# Copyright (c) 2016 Ultimaker B.V.
# Cura is released under the terms of the LGPLv3 or higher.

from .avr_isp import stk500v2, ispBase, intelHex
import serial   # type: ignore
import threading
import time
import queue
import re
import functools

from UM.Application import Application
from UM.Logger import Logger
from cura.PrinterOutputDevice import PrinterOutputDevice, ConnectionState
from UM.Message import Message
from UM.Qt.Duration import DurationFormat

from PyQt5.QtCore import QUrl, pyqtSlot, pyqtSignal, pyqtProperty

from UM.i18n import i18nCatalog
catalog = i18nCatalog("cura")


class USBPrinterOutputDevice(PrinterOutputDevice):
    def __init__(self, serial_port):
        super().__init__(serial_port)
        self.setName(catalog.i18nc("@item:inmenu", "USB printing"))
        self.setShortDescription(catalog.i18nc("@action:button Preceded by 'Ready to'.", "Print via USB"))
        self.setDescription(catalog.i18nc("@info:tooltip", "Print via USB"))
        self.setIconName("print")
        self.setConnectionText(catalog.i18nc("@info:status", "Connected via USB"))

        self._serial = None
        self._serial_port = serial_port
        self._error_state = None

        self._connect_thread = threading.Thread(target = self._connect)
        self._connect_thread.daemon = True

        self._end_stop_thread = None
        self._poll_endstop = False

        # The baud checking is done by sending a number of m105 commands to the printer and waiting for a readable
        # response. If the baudrate is correct, this should make sense, else we get giberish.
        self._required_responses_auto_baud = 3

        self._listen_thread = threading.Thread(target=self._listen)
        self._listen_thread.daemon = True

        self._update_firmware_thread = threading.Thread(target= self._updateFirmware)
        self._update_firmware_thread.daemon = True
        self.firmwareUpdateComplete.connect(self._onFirmwareUpdateComplete)

        self._heatup_wait_start_time = time.time()

        self.jobStateChanged.connect(self._onJobStateChanged)

        ## Queue for commands that need to be send. Used when command is sent when a print is active.
        self._command_queue = queue.Queue()

        self._is_printing = False
        self._is_paused = False

        ## Set when print is started in order to check running time.
        self._print_start_time = None
        self._print_estimated_time = None

        ## Keep track where in the provided g-code the print is
        self._gcode_position = 0

        # List of gcode lines to be printed
        self._gcode = []

        # Check if endstops are ever pressed (used for first run)
        self._x_min_endstop_pressed = False
        self._y_min_endstop_pressed = False
        self._z_min_endstop_pressed = False

        self._x_max_endstop_pressed = False
        self._y_max_endstop_pressed = False
        self._z_max_endstop_pressed = False

        # In order to keep the connection alive we request the temperature every so often from a different extruder.
        # This index is the extruder we requested data from the last time.
        self._temperature_requested_extruder_index = 0

        self._current_z = 0

        self._updating_firmware = False

        self._firmware_file_name = None
        self._firmware_update_finished = False

        self._error_message = None
        self._error_code = 0

    onError = pyqtSignal()

    firmwareUpdateComplete = pyqtSignal()
    firmwareUpdateChange = pyqtSignal()

    endstopStateChanged = pyqtSignal(str ,bool, arguments = ["key","state"])

    def _setTargetBedTemperature(self, temperature):
        Logger.log("d", "Setting bed temperature to %s", temperature)
        self._sendCommand("M140 S%s" % temperature)

    def _setTargetHotendTemperature(self, index, temperature):
        Logger.log("d", "Setting hotend %s temperature to %s", index, temperature)
        self._sendCommand("M104 T%s S%s" % (index, temperature))

    def _setHeadPosition(self, x, y , z, speed):
        self._sendCommand("G0 X%s Y%s Z%s F%s" % (x, y, z, speed))

    def _setHeadX(self, x, speed):
        self._sendCommand("G0 X%s F%s" % (x, speed))

    def _setHeadY(self, y, speed):
        self._sendCommand("G0 Y%s F%s" % (y, speed))

    def _setHeadZ(self, z, speed):
        self._sendCommand("G0 Y%s F%s" % (z, speed))

    def _homeHead(self):
        self._sendCommand("G28 X")
        self._sendCommand("G28 Y")
        
    def _homeX(self):
        self.sendCommand("G28 X")

    def _homeY(self):
        self.sendCommand("G28 Y")

    def _homeBed(self):
        self._sendCommand("G28 Z")

    ##  Updates the target bed temperature from the printer, and emit a signal if it was changed.
    #
    #   /param temperature The new target temperature of the bed.
    #   /return boolean, True if the temperature was changed, false if the new temperature has the same value as the already stored temperature
    def _updateTargetBedTemperature(self, temperature):
        if self._target_bed_temperature == temperature:
            return False
        self._target_bed_temperature = temperature
        self.targetBedTemperatureChanged.emit()
        return True

    ##  Updates the target hotend temperature from the printer, and emit a signal if it was changed.
    #
    #   /param index The index of the hotend.
    #   /param temperature The new target temperature of the hotend.
    #   /return boolean, True if the temperature was changed, false if the new temperature has the same value as the already stored temperature
    def _updateTargetHotendTemperature(self, index, temperature):
        if self._target_hotend_temperatures[index] == temperature:
            return False
        self._target_hotend_temperatures[index] = temperature
        self.targetHotendTemperaturesChanged.emit()
        return True

    ##  A name for the device.
    @pyqtProperty(str, constant = True)
    def name(self):
        return self.getName()

    ##  The address of the device.
    @pyqtProperty(str, constant = True)
    def address(self):
        return self._serial_port

    def startPrint(self):
        self.writeStarted.emit(self)
        active_build_plate_id = Application.getInstance().getBuildPlateModel().activeBuildPlate
        gcode_dict = getattr(Application.getInstance().getController().getScene(), "gcode_dict")
        gcode_list = gcode_dict[active_build_plate_id]

        self._updateJobState("printing")
        self.printGCode(gcode_list)

    def _moveHead(self, x, y, z, speed):
        self._sendCommand("G91")
        self._sendCommand("G0 X%f Y%f Z%f F%f" % (x, y, z, speed))
        self._sendCommand("G90")
        
	# Added to create manual extruder control 2017.11.03
    def _moveExtruder(self, e, speed):
        self._sendCommand("G91")
        self._sendCommand("G0 E%s F%s" % (e, speed))
        self._sendCommand("G90")
    # Added to allow for tool change 2017.11.07
    def _changeTool(self, t):
        self._sendCommand("T%s" % t)

    ## Send a gcode to the machine 2017.12.05
	#  Note that this is a relative move. 
	#  /param com command to be sent
	#  /sa _directGCode Implementation function
    def _directGCode(self, com):
        self._sendCommand(com)

    ##  Start a print based on a g-code.
    #   \param gcode_list List with gcode (strings).
    def printGCode(self, gcode_list):
        Logger.log("d", "Started printing g-code")
        if self._progress or self._connection_state != ConnectionState.connected:
            self._error_message = Message(catalog.i18nc("@info:status", "Unable to start a new job because the printer is busy or not connected."), title = catalog.i18nc("@info:title", "Printer Unavailable"))
            self._error_message.show()
            Logger.log("d", "Printer is busy or not connected, aborting print")
            self.writeError.emit(self)
            return

        self._gcode.clear()
        for layer in gcode_list:
            self._gcode.extend(layer.split("\n"))

        # Reset line number. If this is not done, first line is sometimes ignored
        self._gcode.insert(0, "M110")
        self._gcode_position = 0
        self._is_printing = True
        self._print_start_time = time.time()

        for i in range(0, 4):  # Push first 4 entries before accepting other inputs
            self._sendNextGcodeLine()

        self.writeFinished.emit(self)

    ##  Get the serial port string of this connection.
    #   \return serial port
    def getSerialPort(self):
        return self._serial_port

    ##  Try to connect the serial. This simply starts the thread, which runs _connect.
    def connect(self):
        if not self._updating_firmware and not self._connect_thread.isAlive():
            self._connect_thread.start()

    ##  Private function (threaded) that actually uploads the firmware.
    def _updateFirmware(self):
        Logger.log("d", "Attempting to update firmware")
        self._error_code = 0
        self.setProgress(0, 100)
        self._firmware_update_finished = False

        if self._connection_state != ConnectionState.closed:
            self.close()
        hex_file = intelHex.readHex(self._firmware_file_name)

        if len(hex_file) == 0:
            Logger.log("e", "Unable to read provided hex file. Could not update firmware")
            self._updateFirmwareFailedMissingFirmware()
            return

        programmer = stk500v2.Stk500v2()
        programmer.progress_callback = self.setProgress

        try:
            programmer.connect(self._serial_port)
        except Exception:
            programmer.close()
            pass

        # Give programmer some time to connect. Might need more in some cases, but this worked in all tested cases.
        time.sleep(1)

        if not programmer.isConnected():
            Logger.log("e", "Unable to connect with serial. Could not update firmware")
            self._updateFirmwareFailedCommunicationError()
            return

        self._updating_firmware = True

        try:
            programmer.programChip(hex_file)
            self._updating_firmware = False
        except serial.SerialException as e:
            Logger.log("e", "SerialException while trying to update firmware: <%s>" %(repr(e)))
            self._updateFirmwareFailedIOError()
            return
        except Exception as e:
            Logger.log("e", "Exception while trying to update firmware: <%s>" %(repr(e)))
            self._updateFirmwareFailedUnknown()
            return
        programmer.close()

        self._updateFirmwareCompletedSucessfully()
        return

    ##  Private function which makes sure that firmware update process has failed by missing firmware
    def _updateFirmwareFailedMissingFirmware(self):
        return self._updateFirmwareFailedCommon(4)

    ##  Private function which makes sure that firmware update process has failed by an IO error
    def _updateFirmwareFailedIOError(self):
        return self._updateFirmwareFailedCommon(3)

    ##  Private function which makes sure that firmware update process has failed by a communication problem
    def _updateFirmwareFailedCommunicationError(self):
        return self._updateFirmwareFailedCommon(2)

    ##  Private function which makes sure that firmware update process has failed by an unknown error
    def _updateFirmwareFailedUnknown(self):
        return self._updateFirmwareFailedCommon(1)

    ##  Private common function which makes sure that firmware update process has completed/ended with a set progress state
    def _updateFirmwareFailedCommon(self, code):
        if not code:
            raise Exception("Error code not set!")

        self._error_code = code

        self._firmware_update_finished = True
        self.resetFirmwareUpdate(update_has_finished = True)
        self.progressChanged.emit()
        self.firmwareUpdateComplete.emit()

        return

    ##  Private function which makes sure that firmware update process has successfully completed
    def _updateFirmwareCompletedSucessfully(self):
        self.setProgress(100, 100)
        self._firmware_update_finished = True
        self.resetFirmwareUpdate(update_has_finished = True)
        self.firmwareUpdateComplete.emit()

        return

    ##  Upload new firmware to machine
    #   \param filename full path of firmware file to be uploaded
    def updateFirmware(self, file_name):
        Logger.log("i", "Updating firmware of %s using %s", self._serial_port, file_name)
        self._firmware_file_name = file_name
        self._update_firmware_thread.start()

    @property
    def firmwareUpdateFinished(self):
        return self._firmware_update_finished

    def resetFirmwareUpdate(self, update_has_finished = False):
        self._firmware_update_finished = update_has_finished
        self.firmwareUpdateChange.emit()

    @pyqtSlot()
    def startPollEndstop(self):
        if not self._poll_endstop:
            self._poll_endstop = True
            if self._end_stop_thread is None:
                self._end_stop_thread = threading.Thread(target=self._pollEndStop)
                self._end_stop_thread.daemon = True
            self._end_stop_thread.start()

    @pyqtSlot()
    def stopPollEndstop(self):
        self._poll_endstop = False
        self._end_stop_thread = None

    def _pollEndStop(self):
        while self._connection_state == ConnectionState.connected and self._poll_endstop:
            self.sendCommand("M119")
            time.sleep(0.5)

    ##  Private connect function run by thread. Can be started by calling connect.
    def _connect(self):
        Logger.log("d", "Attempting to connect to %s", self._serial_port)
        self.setConnectionState(ConnectionState.connecting)
        programmer = stk500v2.Stk500v2()
        try:
            programmer.connect(self._serial_port) # Connect with the serial, if this succeeds, it's an arduino based usb device.
            self._serial = programmer.leaveISP()
        except ispBase.IspError as e:
            programmer.close()
            Logger.log("i", "Could not establish connection on %s: %s. Device is not arduino based." %(self._serial_port,str(e)))
        except Exception as e:
            programmer.close()
            Logger.log("i", "Could not establish connection on %s, unknown reasons.  Device is not arduino based." % self._serial_port)

        # If the programmer connected, we know its an atmega based version.
        # Not all that useful, but it does give some debugging information.
        for baud_rate in self._getBaudrateList(): # Cycle all baud rates (auto detect)
            Logger.log("d", "Attempting to connect to printer with serial %s on baud rate %s", self._serial_port, baud_rate)
            if self._serial is None:
                try:
                    self._serial = serial.Serial(str(self._serial_port), baud_rate, timeout = 3, writeTimeout = 10000)
                    time.sleep(10)
                except serial.SerialException:
                    Logger.log("d", "Could not open port %s" % self._serial_port)
                    continue
            else:
                if not self.setBaudRate(baud_rate):
                    continue  # Could not set the baud rate, go to the next

            time.sleep(1.5) # Ensure that we are not talking to the bootloader. 1.5 seconds seems to be the magic number
            sucesfull_responses = 0
            timeout_time = time.time() + 5
            self._serial.write(b"\n")
            self._sendCommand("M105")  # Request temperature, as this should (if baudrate is correct) result in a command with "T:" in it
            while timeout_time > time.time():
                line = self._readline()
                if line is None:
                    Logger.log("d", "No response from serial connection received.")
                    # Something went wrong with reading, could be that close was called.
                    self.setConnectionState(ConnectionState.closed)
                    return

                if b"T:" in line:
                    Logger.log("d", "Correct response for auto-baudrate detection received.")
                    self._serial.timeout = 0.5
                    sucesfull_responses += 1
                    if sucesfull_responses >= self._required_responses_auto_baud:
                        self._serial.timeout = 2 # Reset serial timeout
                        self.setConnectionState(ConnectionState.connected)
                        self._listen_thread.start()  # Start listening
                        Logger.log("i", "Established printer connection on port %s" % self._serial_port)
                        return

                self._sendCommand("M105")  # Send M105 as long as we are listening, otherwise we end up in an undefined state

        Logger.log("e", "Baud rate detection for %s failed", self._serial_port)
        self.close()  # Unable to connect, wrap up.
        self.setConnectionState(ConnectionState.closed)

    ##  Set the baud rate of the serial. This can cause exceptions, but we simply want to ignore those.
    def setBaudRate(self, baud_rate):
        try:
            self._serial.baudrate = baud_rate
            return True
        except Exception as e:
            return False

    ##  Close the printer connection
    def close(self):
        Logger.log("d", "Closing the USB printer connection.")
        if self._connect_thread.isAlive():
            try:
                self._connect_thread.join()
            except Exception as e:
                Logger.log("d", "PrinterConnection.close: %s (expected)", e)
                pass # This should work, but it does fail sometimes for some reason

        self._connect_thread = threading.Thread(target = self._connect)
        self._connect_thread.daemon = True

        self.setConnectionState(ConnectionState.closed)
        if self._serial is not None:
            try:
                self._listen_thread.join()
            except:
                pass
            if self._serial is not None:    # Avoid a race condition when a thread can change the value of self._serial to None
                self._serial.close()

        self._listen_thread = threading.Thread(target = self._listen)
        self._listen_thread.daemon = True
        self._serial = None

    ##  Directly send the command, withouth checking connection state (eg; printing).
    #   \param cmd string with g-code
    def _sendCommand(self, cmd):
        if self._serial is None:
            return

        if "M109" in cmd or "M190" in cmd:
            self._heatup_wait_start_time = time.time()

        try:
            command = (cmd + "\n").encode()
            self._serial.write(b"\n")
            self._serial.write(command)
        except serial.SerialTimeoutException:
            Logger.log("w","Serial timeout while writing to serial port, trying again.")
            try:
                time.sleep(0.5)
                self._serial.write((cmd + "\n").encode())
            except Exception as e:
                Logger.log("e","Unexpected error while writing serial port %s " % e)
                self._setErrorState("Unexpected error while writing serial port %s " % e)
                self.close()
        except Exception as e:
            Logger.log("e","Unexpected error while writing serial port %s" % e)
            self._setErrorState("Unexpected error while writing serial port %s " % e)
            self.close()

    ##  Send a command to printer.
    #   \param cmd string with g-code
    def sendCommand(self, cmd):
        if self._progress:
            self._command_queue.put(cmd)
        elif self._connection_state == ConnectionState.connected:
            self._sendCommand(cmd)

    ##  Set the error state with a message.
    #   \param error String with the error message.
    def _setErrorState(self, error):
        self._updateJobState("error")
        self._error_state = error
        self.onError.emit()

    ##  Request the current scene to be sent to a USB-connected printer.
    #
    #   \param nodes A collection of scene nodes to send. This is ignored.
    #   \param file_name \type{string} A suggestion for a file name to write.
    #   \param filter_by_machine Whether to filter MIME types by machine. This
    #   is ignored.
    #   \param kwargs Keyword arguments.
    def requestWrite(self, nodes, file_name = None, filter_by_machine = False, file_handler = None, **kwargs):
        container_stack = Application.getInstance().getGlobalContainerStack()

        if container_stack.getProperty("machine_gcode_flavor", "value") == "UltiGCode":
            self._error_message = Message(catalog.i18nc("@info:status", "This printer does not support USB printing because it uses UltiGCode flavor."), title = catalog.i18nc("@info:title", "USB Printing"))
            self._error_message.show()
            return
        elif not container_stack.getMetaDataEntry("supports_usb_connection"):
            self._error_message = Message(catalog.i18nc("@info:status", "Unable to start a new job because the printer does not support usb printing."), title = catalog.i18nc("@info:title", "Warning"))
            self._error_message.show()
            return

        self.setJobName(file_name)
        self._print_estimated_time = int(Application.getInstance().getPrintInformation().currentPrintTime.getDisplayString(DurationFormat.Format.Seconds))

        Application.getInstance().getController().setActiveStage("MonitorStage")
        self.startPrint()

    def _setEndstopState(self, endstop_key, value):
        if endstop_key == b"x_min":
            if self._x_min_endstop_pressed != value:
                self.endstopStateChanged.emit("x_min", value)
            self._x_min_endstop_pressed = value
        elif endstop_key == b"y_min":
            if self._y_min_endstop_pressed != value:
                self.endstopStateChanged.emit("y_min", value)
            self._y_min_endstop_pressed = value
        elif endstop_key == b"z_min":
            if self._z_min_endstop_pressed != value:
                self.endstopStateChanged.emit("z_min", value)
            self._z_min_endstop_pressed = value

    ##  Listen thread function.
    def _listen(self):
        Logger.log("i", "Printer connection listen thread started for %s" % self._serial_port)
        container_stack = Application.getInstance().getGlobalContainerStack()
        temperature_request_timeout = time.time()
        ok_timeout = time.time()
        while self._connection_state == ConnectionState.connected:
            line = self._readline()
            if line is None:
                break  # None is only returned when something went wrong. Stop listening

            if time.time() > temperature_request_timeout:
                if self._num_extruders > 1:
                    self._temperature_requested_extruder_index = (self._temperature_requested_extruder_index + 1) % self._num_extruders
                    self.sendCommand("M105 T%d" % (self._temperature_requested_extruder_index))
                else:
                    self.sendCommand("M105")
                self.sendCommand("M114")
                temperature_request_timeout = time.time() + 5

            if line.startswith(b"Error:"):
                # Oh YEAH, consistency.
                # Marlin reports a MIN/MAX temp error as "Error:x\n: Extruder switched off. MAXTEMP triggered !\n"
                # But a bed temp error is reported as "Error: Temperature heated bed switched off. MAXTEMP triggered !!"
                # So we can have an extra newline in the most common case. Awesome work people.
                if re.match(b"Error:[0-9]\n", line):
                    line = line.rstrip() + self._readline()

                # Skip the communication errors, as those get corrected.
                if b"Extruder switched off" in line or b"Temperature heated bed switched off" in line or b"Something is wrong, please turn off the printer." in line:
                    if not self.hasError():
                        self._setErrorState(line[6:])

            elif b" T:" in line or line.startswith(b"T:"):  # Temperature message
                temperature_matches = re.findall(b"T(\d):(-{,1}[\d\.]+) \/(-{,1}[\d\.]+)", line)
                temperature_set = False
                try:
                    for match in temperature_matches:
                        if match[0]:
                            extruder_nr = int(match[0])
                            if extruder_nr >= container_stack.getProperty("machine_extruder_count", "value"):
                                continue
                            if match[1]:
                                self._setHotendTemperature(extruder_nr, float(match[1]))
                                temperature_set = True
                            if match[2]:
                                self._updateTargetHotendTemperature(extruder_nr, float(match[2]))
                        #else:
                        #    requested_temperatures = match
                    #if not temperature_set and requested_temperatures:
                    #    if requested_temperatures[1]:
                    #        self._setHotendTemperature(self._temperature_requested_extruder_index, float(requested_temperatures[1]))
                    #    if requested_temperatures[2]:
                    #        self._updateTargetHotendTemperature(self._temperature_requested_extruder_index, float(requested_temperatures[2]))
                except:
                    Logger.log("w", "Could not parse hotend temperatures from response: %s", line)
                # Check if there's also a bed temperature
                temperature_matches = re.findall(b"B:(-{,1}[\d\.]+) \/(-{,1}[\d\.]+)", line)
                if container_stack.getProperty("machine_heated_bed", "value") and len(temperature_matches) > 0:
                    match = temperature_matches[0]
                    try:
                        if match[0]:
                            self._setBedTemperature(float(match[0]))
                        if match[1]:
                            self._updateTargetBedTemperature(float(match[1]))
                    except:
                        Logger.log("w", "Could not parse bed temperature from response: %s", line)
            elif line.startswith(b"X:") and b"Y:" in line and b"Z:" in line:  # Position message
                X_match = re.findall(b"X:(-{,1}[\d\.]+)", line)
                Y_match = re.findall(b"Y:(-{,1}[\d\.]+)", line)
                Z_match = re.findall(b"Z:(-{,1}[\d\.]+)", line)
                #X_match = X_match[0]
                #Y_match = Y_match[0]
                #Z_match = Z_match[0]
                if len(X_match) > 0:
                    try:
                        if X_match[0] and Y_match[0] and Z_match[0]:
                            self._updateHeadPosition(float(X_match[0]),float(Y_match[0]),float(Z_match[0]))
                            Logger.log("i","Position: X: %f\tY: %f\tZ: %f" % (self.headX,self.headY,self.headZ))
                        else:
                            Logger.log("w","Could not receive full position from response: %s", line)
                    except:
                        Logger.log("w", "Could not parse position from response: %s", line)

            elif b"_min" in line or b"_max" in line:
                tag, value = line.split(b":", 1)
                self._setEndstopState(tag,(b"H" in value or b"TRIGGERED" in value))

            if self._is_printing:
                if line == b"" and time.time() > ok_timeout:
                    line = b"ok"  # Force a timeout (basically, send next command)

                if b"ok" in line:
                    ok_timeout = time.time() + 5
                    if not self._command_queue.empty():
                        self._sendCommand(self._command_queue.get())
                    elif self._is_paused:
                        line = b""  # Force getting temperature as keep alive
                    else:
                        self._sendNextGcodeLine()
                elif b"resend" in line.lower() or b"rs" in line:  # Because a resend can be asked with "resend" and "rs"
                    try:
                        Logger.log("d", "Got a resend response")
                        self._gcode_position = int(line.replace(b"N:",b" ").replace(b"N",b" ").replace(b":",b" ").split()[-1])
                    except:
                        if b"rs" in line:
                            self._gcode_position = int(line.split()[1])

            # Request the temperature on comm timeout (every 2 seconds) when we are not printing.)
            if line == b"":
                if self._num_extruders > 1:
                    self._temperature_requested_extruder_index = (self._temperature_requested_extruder_index + 1) % self._num_extruders
                    self.sendCommand("M105 T%d" % self._temperature_requested_extruder_index)
                else:
                    self.sendCommand("M105")
                self.sendCommand("M114")

        Logger.log("i", "Printer connection listen thread stopped for %s" % self._serial_port)

    ##  Send next Gcode in the gcode list
    def _sendNextGcodeLine(self):
        if self._gcode_position >= len(self._gcode):
            return
        line = self._gcode[self._gcode_position]

        if ";" in line:
            line = line[:line.find(";")]
        line = line.strip()

        # Don't send empty lines. But we do have to send something, so send
        # m105 instead.
        # Don't send the M0 or M1 to the machine, as M0 and M1 are handled as
        # an LCD menu pause.
        if line == "" or line == "M0" or line == "M1":
            line = "M105"
        try:
            if ("G0" in line or "G1" in line) and "Z" in line:
                z = float(re.search("Z([0-9\.]*)", line).group(1))
                if self._current_z != z:
                    self._current_z = z
        except Exception as e:
            Logger.log("e", "Unexpected error with printer connection, could not parse current Z: %s: %s" % (e, line))
            self._setErrorState("Unexpected error: %s" %e)
        checksum = functools.reduce(lambda x,y: x^y, map(ord, "N%d%s" % (self._gcode_position, line)))

        self._sendCommand("N%d%s*%d" % (self._gcode_position, line, checksum))

        progress = (self._gcode_position / len(self._gcode))

        elapsed_time = int(time.time() - self._print_start_time)
        self.setTimeElapsed(elapsed_time)
        estimated_time = self._print_estimated_time
        if progress > .1:
            estimated_time = self._print_estimated_time * (1-progress) + elapsed_time
        self.setTimeTotal(estimated_time)

        self._gcode_position += 1
        self.setProgress(progress * 100)
        self.progressChanged.emit()

    ##  Set the state of the print.
    #   Sent from the print monitor
    def _setJobState(self, job_state):
        if job_state == "pause":
            self._is_paused = True
            self._updateJobState("paused")
        elif job_state == "print":
            self._is_paused = False
            self._updateJobState("printing")
        elif job_state == "abort":
            self.cancelPrint()

    def _onJobStateChanged(self):
        # clear the job name & times when printing is done or aborted
        if self._job_state == "ready":
            self.setJobName("")
            self.setTimeElapsed(0)
            self.setTimeTotal(0)

    ##  Set the progress of the print.
    #   It will be normalized (based on max_progress) to range 0 - 100
    def setProgress(self, progress, max_progress = 100):
        self._progress = (progress / max_progress) * 100  # Convert to scale of 0-100
        if self._progress == 100:
            # Printing is done, reset progress
            self._gcode_position = 0
            self.setProgress(0)
            self._is_printing = False
            self._is_paused = False
            self._updateJobState("ready")
        self.progressChanged.emit()

    ##  Cancel the current print. Printer connection wil continue to listen.
    def cancelPrint(self):
        self._gcode_position = 0
        self.setProgress(0)
        self._gcode = []

        # Turn off temperatures, fan and steppers
        self._sendCommand("M140 S0")
        self._sendCommand("M104 S0")
        self._sendCommand("M107")
        # Home XY to prevent nozzle resting on aborted print
        # Don't home bed because it may crash the printhead into the print on printers that home on the bottom
        self.homeHead()
        self._sendCommand("M84")
        self._is_printing = False
        self._is_paused = False
        self._updateJobState("ready")
        Application.getInstance().getController().setActiveStage("PrepareStage")

    ##  Check if the process did not encounter an error yet.
    def hasError(self):
        return self._error_state is not None

    ##  private read line used by printer connection to listen for data on serial port.
    def _readline(self):
        if self._serial is None:
            return None
        try:
            ret = self._serial.readline()
        except Exception as e:
            Logger.log("e", "Unexpected error while reading serial port. %s" % e)
            self._setErrorState("Printer has been disconnected")
            self.close()
            return None
        return ret

    ##  Create a list of baud rates at which we can communicate.
    #   \return list of int
    def _getBaudrateList(self):
        ret = [115200, 250000, 230400, 57600, 38400, 19200, 9600]
        return ret

    def _onFirmwareUpdateComplete(self):
        self._update_firmware_thread.join()
        self._update_firmware_thread = threading.Thread(target = self._updateFirmware)
        self._update_firmware_thread.daemon = True

        self.connect()

    ##  Pre-heats the heated bed of the printer, if it has one.
    #
    #   \param temperature The temperature to heat the bed to, in degrees
    #   Celsius.
    #   \param duration How long the bed should stay warm, in seconds. This is
    #   ignored because there is no g-code to set this.
    @pyqtSlot(float, float)
    def preheatBed(self, temperature, duration):
        Logger.log("i", "Pre-heating the bed to %i degrees.", temperature)
        self._setTargetBedTemperature(temperature)
        self.preheatBedRemainingTimeChanged.emit()

    ##  Cancels pre-heating the heated bed of the printer.
    #
    #   If the bed is not pre-heated, nothing happens.
    @pyqtSlot()
    def cancelPreheatBed(self):
        Logger.log("i", "Cancelling pre-heating of the bed.")
        self._setTargetBedTemperature(0)
        self.preheatBedRemainingTimeChanged.emit()
