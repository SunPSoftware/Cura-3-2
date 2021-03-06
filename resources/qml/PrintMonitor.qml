// Copyright (c) 2017 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.8
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import UM 1.2 as UM
import Cura 1.0 as Cura

Column
{
    id: printMonitor
    property var connectedPrinter: Cura.MachineManager.printerOutputDevices.length >= 1 ? Cura.MachineManager.printerOutputDevices[0] : null

    Cura.ExtrudersModel
    {
        id: extrudersModel
        simpleNames: true
    }

    Rectangle
    {
        id: connectedPrinterHeader
        width: parent.width
        height: Math.round(childrenRect.height + UM.Theme.getSize("default_margin").height * 2)
        color: UM.Theme.getColor("setting_category")

        Label
        {
            id: connectedPrinterNameLabel
            font: UM.Theme.getFont("large")
            color: UM.Theme.getColor("text")
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: UM.Theme.getSize("default_margin").width
            text: connectedPrinter != null ? connectedPrinter.name : catalog.i18nc("@info:status", "No printer connected")
        }
        Label
        {
            id: connectedPrinterAddressLabel
            text: (connectedPrinter != null && connectedPrinter.address != null) ? connectedPrinter.address : ""
            font: UM.Theme.getFont("small")
            color: UM.Theme.getColor("text_inactive")
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: UM.Theme.getSize("default_margin").width
        }
        Label
        {
            text: connectedPrinter != null ? connectedPrinter.connectionText : catalog.i18nc("@info:status", "The printer is not connected.")
            color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
            font: UM.Theme.getFont("very_small")
            wrapMode: Text.WordWrap
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width
            anchors.right: parent.right
            anchors.rightMargin: UM.Theme.getSize("default_margin").width
            anchors.top: connectedPrinterNameLabel.bottom
        }
    }

    Rectangle
    {
        color: UM.Theme.getColor("sidebar_lining")
        width: parent.width
        height: childrenRect.height

        Flow
        {
            id: extrudersGrid
            spacing: UM.Theme.getSize("sidebar_lining_thin").width
            width: parent.width

            Repeater
            {
                id: extrudersRepeater
                model: machineExtruderCount.properties.value

                delegate: Rectangle
                {
                    id: extruderRectangle
                    color: UM.Theme.getColor("sidebar")
                    width: index == machineExtruderCount.properties.value - 1 && index % 2 == 0 ? extrudersGrid.width : Math.round(extrudersGrid.width / 2 - UM.Theme.getSize("sidebar_lining_thin").width / 2)
                    height: UM.Theme.getSize("sidebar_extruder_box").height

                    Label //Extruder name.
                    {
                        text: Cura.ExtruderManager.getExtruderName(index) != "" ? Cura.ExtruderManager.getExtruderName(index) : catalog.i18nc("@label", "Extruder")
                        color: UM.Theme.getColor("text")
                        font: UM.Theme.getFont("default")
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: UM.Theme.getSize("default_margin").width
                    }

                    Label //Target temperature.
                    {
                        id: extruderTargetTemperature
                        text: (connectedPrinter != null && connectedPrinter.hotendIds[index] != null && connectedPrinter.targetHotendTemperatures[index] != null) ? Math.round(connectedPrinter.targetHotendTemperatures[index]) + "°C" : ""
                        font: UM.Theme.getFont("small")
                        color: UM.Theme.getColor("text_inactive")
                        anchors.right: parent.right
                        anchors.rightMargin: UM.Theme.getSize("default_margin").width
                        anchors.bottom: extruderTemperature.bottom

                        MouseArea //For tooltip.
                        {
                            id: extruderTargetTemperatureTooltipArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onHoveredChanged:
                            {
                                if (containsMouse)
                                {
                                    base.showTooltip(
                                        base,
                                        {x: 0, y: extruderTargetTemperature.mapToItem(base, 0, -parent.height / 4).y},
                                        catalog.i18nc("@tooltip", "The target temperature of the hotend. The hotend will heat up or cool down towards this temperature. If this is 0, the hotend heating is turned off.")
                                    );
                                }
                                else
                                {
                                    base.hideTooltip();
                                }
                            }
                        }
                    }
                    Label //Temperature indication.
                    {
                        id: extruderTemperature
                        text: (connectedPrinter != null && connectedPrinter.hotendIds[index] != null && connectedPrinter.hotendTemperatures[index] != null) ? Math.round(connectedPrinter.hotendTemperatures[index]) + "°C" : ""
                        color: UM.Theme.getColor("text")
                        font: UM.Theme.getFont("large")
                        anchors.right: extruderTargetTemperature.left
                        anchors.top: parent.top
                        anchors.margins: UM.Theme.getSize("default_margin").width

                        MouseArea //For tooltip.
                        {
                            id: extruderTemperatureTooltipArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onHoveredChanged:
                            {
                                if (containsMouse)
                                {
                                    base.showTooltip(
                                        base,
                                        {x: 0, y: parent.mapToItem(base, 0, -parent.height / 4).y},
                                        catalog.i18nc("@tooltip", "The current temperature of this extruder.")
                                    );
                                }
                                else
                                {
                                    base.hideTooltip();
                                }
                            }
                        }
                    }
					Row
					{
						id: extruderTempRow
						width: base.width - 2 * UM.Theme.getSize("default_margin").width
						height: childrenRect.height + UM.Theme.getSize("default_margin").width
						anchors.left: parent.left
						anchors.leftMargin: UM.Theme.getSize("default_margin").width
						anchors.right: parent.right
						anchors.rightMargin: UM.Theme.getSize("default_margin").width
						anchors.top: extruderTemperature.bottom

						spacing: UM.Theme.getSize("default_margin").width

						Rectangle //Input field for pre-heat temperature.
						{
							id: extruderTempControl
							color: !enabled ? UM.Theme.getColor("setting_control_disabled") : UM.Theme.getColor("setting_validation_ok")
							enabled:
							{
								if (connectedPrinter == null)
								{
									return false; //Can't preheat if not connected.
								}
								if (!connectedPrinter.acceptsCommands)
								{
									return false; //Not allowed to do anything.
								}
								if (connectedPrinter.jobState == "printing" || connectedPrinter.jobState == "pre_print" || connectedPrinter.jobState == "resuming" || connectedPrinter.jobState == "pausing" || connectedPrinter.jobState == "paused" || connectedPrinter.jobState == "error" || connectedPrinter.jobState == "offline")
								{
									return false; //Printer is in a state where it can't react to pre-heating.
								}
								return true;
							}
							border.width: UM.Theme.getSize("default_lining").width
							border.color: !enabled ? UM.Theme.getColor("setting_control_disabled_border") : preheatTemperatureInputMouseArea.containsMouse ? UM.Theme.getColor("setting_control_border_highlight") : UM.Theme.getColor("setting_control_border")
							//anchors.left: extruderTempRow.left
							//anchors.leftMargin: UM.Theme.getSize("default_margin").width
							//anchors.top: extruderTempRow.top
							//anchors.topMargin: UM.Theme.getSize("default_margin").height
							anchors.verticalCenter: extruderTempOff.verticalCenter
							width: height + UM.Theme.getSize("default_margin").width * 2.75 //UM.Theme.getSize("setting_control").width
							height: UM.Theme.getSize("setting_control").height
							visible: connectedPrinter != null 
							Rectangle //Highlight of input field.
							{
								anchors.fill: parent
								anchors.margins: UM.Theme.getSize("default_lining").width
								color: UM.Theme.getColor("setting_control_highlight")
								opacity: preheatTemperatureControl.hovered ? 1.0 : 0
							}
							Label //Maximum temperature indication.
							{
								text: "" + "°C"
								color: UM.Theme.getColor("setting_unit")
								font: UM.Theme.getFont("default")
								anchors.right: parent.right
								anchors.rightMargin: UM.Theme.getSize("setting_unit_margin").width
								anchors.verticalCenter: parent.verticalCenter
							}
							TextInput
							{
								id: extruderTempInput
								font: UM.Theme.getFont("default")
								color: !enabled ? UM.Theme.getColor("setting_control_disabled_text") : UM.Theme.getColor("setting_control_text")
								selectByMouse: true
								maximumLength: 10
								enabled: parent.enabled
								validator: RegExpValidator { regExp: /^-?[0-9]{0,9}[.,]?[0-9]{0,10}$/ } //Floating point regex.
								anchors.left: parent.left
								anchors.leftMargin: UM.Theme.getSize("setting_unit_margin").width
								anchors.right: parent.right
								anchors.verticalCenter: parent.verticalCenter
								renderType: Text.NativeRendering

							}
						}

						Button
						{
							text: "Set";
							height: UM.Theme.getSize("setting_control").height
							width: height + UM.Theme.getSize("default_margin").width
							anchors.top: parent.top
							//anchors.right: extruderTempOff.left
							//anchors.rightMargin: UM.Theme.getSize("setting_unit_margin").width
							anchors.topMargin: UM.Theme.getSize("setting_unit_margin").height

							style: textButtonStyle

							onClicked:
							{
								connectedPrinter.setTargetHotendTemperature(index, extruderTempInput.text)
							}
						}
						Button
						{
							id: extruderTempOff
							text: "Off";
							height: UM.Theme.getSize("setting_control").height
							width: height + UM.Theme.getSize("default_margin").width
							anchors.top: parent.top
							//anchors.right: parent.right
							//anchors.rightMargin: UM.Theme.getSize("setting_unit_margin").width
							anchors.topMargin: UM.Theme.getSize("setting_unit_margin").height

							style: textButtonStyle

							onClicked:
							{
								connectedPrinter.setTargetHotendTemperature(index, "0")
							}
						}
					}
                    Rectangle //Material colour indication.
                    {
                        id: materialColor
                        width: Math.round(materialName.height * 0.75)
                        height: Math.round(materialName.height * 0.75)
                        radius: width / 2
                        color: (connectedPrinter != null && connectedPrinter.materialColors[index] != null && connectedPrinter.materialIds[index] != "") ? connectedPrinter.materialColors[index] : "#00000000"
                        border.width: UM.Theme.getSize("default_lining").width
                        border.color: UM.Theme.getColor("lining")
                        visible: connectedPrinter != null && connectedPrinter.materialColors[index] != null && connectedPrinter.materialIds[index] != ""
                        anchors.left: parent.left
                        anchors.leftMargin: UM.Theme.getSize("default_margin").width
                        anchors.verticalCenter: materialName.verticalCenter

                        MouseArea //For tooltip.
                        {
                            id: materialColorTooltipArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onHoveredChanged:
                            {
                                if (containsMouse)
                                {
                                    base.showTooltip(
                                        base,
                                        {x: 0, y: parent.mapToItem(base, 0, -parent.height / 2).y},
                                        catalog.i18nc("@tooltip", "The colour of the material in this extruder.")
                                    );
                                }
                                else
                                {
                                    base.hideTooltip();
                                }
                            }
                        }
                    }
                    Label //Material name.
                    {
                        id: materialName
                        text: (connectedPrinter != null && connectedPrinter.materialNames[index] != null && connectedPrinter.materialIds[index] != "") ? connectedPrinter.materialNames[index] : ""
                        font: UM.Theme.getFont("default")
                        color: UM.Theme.getColor("text")
                        anchors.left: materialColor.right
                        anchors.bottom: parent.bottom
						anchors.top: extruderTempRow.botttom
                        anchors.margins: UM.Theme.getSize("default_margin").width

                        MouseArea //For tooltip.
                        {
                            id: materialNameTooltipArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onHoveredChanged:
                            {
                                if (containsMouse)
                                {
                                    base.showTooltip(
                                        base,
                                        {x: 0, y: parent.mapToItem(base, 0, 0).y},
                                        catalog.i18nc("@tooltip", "The material in this extruder.")
                                    );
                                }
                                else
                                {
                                    base.hideTooltip();
                                }
                            }
                        }
                    }
                    Label //Variant name.
                    {
                        id: variantName
                        text: (connectedPrinter != null && connectedPrinter.hotendIds[index] != null) ? connectedPrinter.hotendIds[index] : ""
                        font: UM.Theme.getFont("default")
                        color: UM.Theme.getColor("text")
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
						anchors.top: extruderTempRow.bottom
                        anchors.margins: UM.Theme.getSize("default_margin").width

                        MouseArea //For tooltip.
                        {
                            id: variantNameTooltipArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onHoveredChanged:
                            {
                                if (containsMouse)
                                {
                                    base.showTooltip(
                                        base,
                                        {x: 0, y: parent.mapToItem(base, 0, -parent.height / 4).y},
                                        catalog.i18nc("@tooltip", "The nozzle inserted in this extruder.")
                                    );
                                }
                                else
                                {
                                    base.hideTooltip();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle
    {
        color: UM.Theme.getColor("sidebar_lining")
        width: parent.width
        height: UM.Theme.getSize("sidebar_lining_thin").width
    }

    Rectangle
    {
        color: UM.Theme.getColor("sidebar")
        width: parent.width
        height: machineHeatedBed.properties.value == "True" ? UM.Theme.getSize("sidebar_extruder_box").height : 0
        visible: machineHeatedBed.properties.value == "True"

        Label //Build plate label.
        {
            text: catalog.i18nc("@label", "Build plate")
            font: UM.Theme.getFont("default")
            color: UM.Theme.getColor("text")
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: UM.Theme.getSize("default_margin").width
        }
        Label //Target temperature.
        {
            id: bedTargetTemperature
            text: connectedPrinter != null ? connectedPrinter.targetBedTemperature + "°C" : ""
            font: UM.Theme.getFont("small")
            color: UM.Theme.getColor("text_inactive")
            anchors.right: parent.right
            anchors.rightMargin: UM.Theme.getSize("default_margin").width
            anchors.bottom: bedCurrentTemperature.bottom

            MouseArea //For tooltip.
            {
                id: bedTargetTemperatureTooltipArea
                hoverEnabled: true
                anchors.fill: parent
                onHoveredChanged:
                {
                    if (containsMouse)
                    {
                        base.showTooltip(
                            base,
                            {x: 0, y: bedTargetTemperature.mapToItem(base, 0, -parent.height / 4).y},
                            catalog.i18nc("@tooltip", "The target temperature of the heated bed. The bed will heat up or cool down towards this temperature. If this is 0, the bed heating is turned off.")
                        );
                    }
                    else
                    {
                        base.hideTooltip();
                    }
                }
            }
        }
        Label //Current temperature.
        {
            id: bedCurrentTemperature
            text: connectedPrinter != null ? connectedPrinter.bedTemperature + "°C" : ""
            font: UM.Theme.getFont("large")
            color: UM.Theme.getColor("text")
            anchors.right: bedTargetTemperature.left
            anchors.top: parent.top
            anchors.margins: UM.Theme.getSize("default_margin").width

            MouseArea //For tooltip.
            {
                id: bedTemperatureTooltipArea
                hoverEnabled: true
                anchors.fill: parent
                onHoveredChanged:
                {
                    if (containsMouse)
                    {
                        base.showTooltip(
                            base,
                            {x: 0, y: bedCurrentTemperature.mapToItem(base, 0, -parent.height / 4).y},
                            catalog.i18nc("@tooltip", "The current temperature of the heated bed.")
                        );
                    }
                    else
                    {
                        base.hideTooltip();
                    }
                }
            }
        }
        Rectangle //Input field for pre-heat temperature.
        {
            id: preheatTemperatureControl
            color: !enabled ? UM.Theme.getColor("setting_control_disabled") : showError ? UM.Theme.getColor("setting_validation_error_background") : UM.Theme.getColor("setting_validation_ok")
            property var showError:
            {
                if(bedTemperature.properties.maximum_value != "None" && bedTemperature.properties.maximum_value <  Math.round(preheatTemperatureInput.text))
                {
                    return true;
                } else
                {
                    return false;
                }
            }
            enabled:
            {
                if (connectedPrinter == null)
                {
                    return false; //Can't preheat if not connected.
                }
                if (!connectedPrinter.acceptsCommands)
                {
                    return false; //Not allowed to do anything.
                }
                if (connectedPrinter.jobState == "printing" || connectedPrinter.jobState == "pre_print" || connectedPrinter.jobState == "resuming" || connectedPrinter.jobState == "pausing" || connectedPrinter.jobState == "paused" || connectedPrinter.jobState == "error" || connectedPrinter.jobState == "offline")
                {
                    return false; //Printer is in a state where it can't react to pre-heating.
                }
                return true;
            }
            border.width: UM.Theme.getSize("default_lining").width
            border.color: !enabled ? UM.Theme.getColor("setting_control_disabled_border") : preheatTemperatureInputMouseArea.containsMouse ? UM.Theme.getColor("setting_control_border_highlight") : UM.Theme.getColor("setting_control_border")
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width
            anchors.bottom: parent.bottom
            anchors.bottomMargin: UM.Theme.getSize("default_margin").height
            width: UM.Theme.getSize("setting_control").width
            height: UM.Theme.getSize("setting_control").height
            visible: connectedPrinter != null ? connectedPrinter.canPreHeatBed: true
            Rectangle //Highlight of input field.
            {
                anchors.fill: parent
                anchors.margins: UM.Theme.getSize("default_lining").width
                color: UM.Theme.getColor("setting_control_highlight")
                opacity: preheatTemperatureControl.hovered ? 1.0 : 0
            }
            Label //Maximum temperature indication.
            {
                text: (bedTemperature.properties.maximum_value != "None" ? bedTemperature.properties.maximum_value : "") + "°C"
                color: UM.Theme.getColor("setting_unit")
                font: UM.Theme.getFont("default")
                anchors.right: parent.right
                anchors.rightMargin: UM.Theme.getSize("setting_unit_margin").width
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea //Change cursor on hovering.
            {
                id: preheatTemperatureInputMouseArea
                hoverEnabled: true
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor

                onHoveredChanged:
                {
                    if (containsMouse)
                    {
                        base.showTooltip(
                            base,
                            {x: 0, y: preheatTemperatureInputMouseArea.mapToItem(base, 0, 0).y},
                            catalog.i18nc("@tooltip of temperature input", "The temperature to pre-heat the bed to.")
                        );
                    }
                    else
                    {
                        base.hideTooltip();
                    }
                }
            }
            TextInput
            {
                id: preheatTemperatureInput
                font: UM.Theme.getFont("default")
                color: !enabled ? UM.Theme.getColor("setting_control_disabled_text") : UM.Theme.getColor("setting_control_text")
                selectByMouse: true
                maximumLength: 10
                enabled: parent.enabled
                validator: RegExpValidator { regExp: /^-?[0-9]{0,9}[.,]?[0-9]{0,10}$/ } //Floating point regex.
                anchors.left: parent.left
                anchors.leftMargin: UM.Theme.getSize("setting_unit_margin").width
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering

                Component.onCompleted:
                {
                    if (!bedTemperature.properties.value)
                    {
                        text = "";
                    }
                    if ((bedTemperature.resolve != "None" && bedTemperature.resolve) && (bedTemperature.stackLevels[0] != 0) && (bedTemperature.stackLevels[0] != 1))
                    {
                        // We have a resolve function. Indicates that the setting is not settable per extruder and that
                        // we have to choose between the resolved value (default) and the global value
                        // (if user has explicitly set this).
                        text = bedTemperature.resolve;
                    }
                    else
                    {
                        text = bedTemperature.properties.value;
                    }
                }
            }
        }

        UM.RecolorImage
        {
            id: preheatCountdownIcon
            width: UM.Theme.getSize("save_button_specs_icons").width
            height: UM.Theme.getSize("save_button_specs_icons").height
            sourceSize.width: width
            sourceSize.height: height
            color: UM.Theme.getColor("text")
            visible: preheatCountdown.visible
            source: UM.Theme.getIcon("print_time")
            anchors.right: preheatCountdown.left
            anchors.rightMargin: Math.round(UM.Theme.getSize("default_margin").width / 2)
            anchors.verticalCenter: preheatCountdown.verticalCenter
        }

        Timer
        {
            id: preheatUpdateTimer
            interval: 100 //Update every 100ms. You want to update every 1s, but then you have one timer for the updating running out of sync with the actual date timer and you might skip seconds.
            running: connectedPrinter != null && connectedPrinter.preheatBedRemainingTime != ""
            repeat: true
            onTriggered: update()
            property var endTime: new Date() //Set initial endTime to be the current date, so that the endTime has initially already passed and the timer text becomes invisible if you were to update.
            function update()
            {
                preheatCountdown.text = ""
                if (connectedPrinter != null)
                {
                    preheatCountdown.text = connectedPrinter.preheatBedRemainingTime;
                }
                if (preheatCountdown.text == "") //Either time elapsed or not connected.
                {
                    stop();
                }
            }
        }
        Label
        {
            id: preheatCountdown
            text: connectedPrinter != null ? connectedPrinter.preheatBedRemainingTime : ""
            visible: text != "" //Has no direct effect, but just so that we can link visibility of clock icon to visibility of the countdown text.
            font: UM.Theme.getFont("default")
            color: UM.Theme.getColor("text")
            anchors.right: preheatButton.left
            anchors.rightMargin: UM.Theme.getSize("default_margin").width
            anchors.verticalCenter: preheatButton.verticalCenter
        }

        Button //The pre-heat button.
        {
            id: preheatButton
            height: UM.Theme.getSize("setting_control").height
            visible: connectedPrinter != null ? connectedPrinter.canPreHeatBed: true
            enabled:
            {
                if (!preheatTemperatureControl.enabled)
                {
                    return false; //Not connected, not authenticated or printer is busy.
                }
                if (preheatUpdateTimer.running)
                {
                    return true; //Can always cancel if the timer is running.
                }
                if (bedTemperature.properties.minimum_value != "None" && Math.round(preheatTemperatureInput.text) < Math.round(bedTemperature.properties.minimum_value))
                {
                    return false; //Target temperature too low.
                }
                if (bedTemperature.properties.maximum_value != "None" && Math.round(preheatTemperatureInput.text) > Math.round(bedTemperature.properties.maximum_value))
                {
                    return false; //Target temperature too high.
                }
                /*if (Math.round(preheatTemperatureInput.text) == 0)
                {
                    return false; //Setting the temperature to 0 is not allowed (since that cancels the pre-heating).
                }*/
                return true; //Preconditions are met.
            }
            anchors.right: bedHeatOffButton.left
            anchors.bottom: parent.bottom
            anchors.margins: UM.Theme.getSize("default_margin").width
            style: ButtonStyle {
                background: Rectangle
                {
                    border.width: UM.Theme.getSize("default_lining").width
                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                    border.color:
                    {
                        if(!control.enabled)
                        {
                            return UM.Theme.getColor("action_button_disabled_border");
                        }
                        else if(control.pressed)
                        {
                            return UM.Theme.getColor("action_button_active_border");
                        }
                        else if(control.hovered)
                        {
                            return UM.Theme.getColor("action_button_hovered_border");
                        }
                        else
                        {
                            return UM.Theme.getColor("action_button_border");
                        }
                    }
                    color:
                    {
                        if(!control.enabled)
                        {
                            return UM.Theme.getColor("action_button_disabled");
                        }
                        else if(control.pressed)
                        {
                            return UM.Theme.getColor("action_button_active");
                        }
                        else if(control.hovered)
                        {
                            return UM.Theme.getColor("action_button_hovered");
                        }
                        else
                        {
                            return UM.Theme.getColor("action_button");
                        }
                    }
                    Behavior on color
                    {
                        ColorAnimation
                        {
                            duration: 50
                        }
                    }

                    Label
                    {
                        id: actualLabel
                        anchors.centerIn: parent
                        color:
                        {
                            if(!control.enabled)
                            {
                                return UM.Theme.getColor("action_button_disabled_text");
                            }
                            else if(control.pressed)
                            {
                                return UM.Theme.getColor("action_button_active_text");
                            }
                            else if(control.hovered)
                            {
                                return UM.Theme.getColor("action_button_hovered_text");
                            }
                            else
                            {
                                return UM.Theme.getColor("action_button_text");
                            }
                        }
                        font: UM.Theme.getFont("action_button")
                        text: preheatUpdateTimer.running ? catalog.i18nc("@button Cancel pre-heating", "Cancel") : catalog.i18nc("@button", "Bed Set")
                    }
                }
            }

            onClicked:
            {
                if (!preheatUpdateTimer.running)
                {
                    connectedPrinter.preheatBed(preheatTemperatureInput.text, connectedPrinter.preheatBedTimeout);
                    preheatUpdateTimer.start();
                    preheatUpdateTimer.update(); //Update once before the first timer is triggered.
                }
                else
                {
                    connectedPrinter.cancelPreheatBed();
                    preheatUpdateTimer.update();
                }
            }

            onHoveredChanged:
            {
                if (hovered)
                {
                    base.showTooltip(
                        base,
                        {x: 0, y: preheatButton.mapToItem(base, 0, 0).y},
                        catalog.i18nc("@tooltip of pre-heat", "Heat the bed in advance before printing. You can continue adjusting your print while it is heating, and you won't have to wait for the bed to heat up when you're ready to print.")
                    );
                }
                else
                {
                    base.hideTooltip();
                }
            }
        }
		Button //The bed heat off button.
        {
            id: bedHeatOffButton
            height: UM.Theme.getSize("setting_control").height
            visible: connectedPrinter != null ? connectedPrinter.canPreHeatBed: true
            enabled:
            {
                if (!preheatTemperatureControl.enabled)
                {
                    return false; //Not connected, not authenticated or printer is busy.
                }
                if (preheatUpdateTimer.running)
                {
                    return true; //Can always cancel if the timer is running.
                }
                return true; //Preconditions are met.
            }
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: UM.Theme.getSize("default_margin").width
            style: ButtonStyle {
                background: Rectangle
                {
                    border.width: UM.Theme.getSize("default_lining").width
                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                    border.color:
                    {
                        if(!control.enabled)
                        {
                            return UM.Theme.getColor("action_button_disabled_border");
                        }
                        else if(control.pressed)
                        {
                            return UM.Theme.getColor("action_button_active_border");
                        }
                        else if(control.hovered)
                        {
                            return UM.Theme.getColor("action_button_hovered_border");
                        }
                        else
                        {
                            return UM.Theme.getColor("action_button_border");
                        }
                    }
                    color:
                    {
                        if(!control.enabled)
                        {
                            return UM.Theme.getColor("action_button_disabled");
                        }
                        else if(control.pressed)
                        {
                            return UM.Theme.getColor("action_button_active");
                        }
                        else if(control.hovered)
                        {
                            return UM.Theme.getColor("action_button_hovered");
                        }
                        else
                        {
                            return UM.Theme.getColor("action_button");
                        }
                    }
                    Behavior on color
                    {
                        ColorAnimation
                        {
                            duration: 50
                        }
                    }

                    Label
                    {
                        id: actualLabel
                        anchors.centerIn: parent
                        color:
                        {
                            if(!control.enabled)
                            {
                                return UM.Theme.getColor("action_button_disabled_text");
                            }
                            else if(control.pressed)
                            {
                                return UM.Theme.getColor("action_button_active_text");
                            }
                            else if(control.hovered)
                            {
                                return UM.Theme.getColor("action_button_hovered_text");
                            }
                            else
                            {
                                return UM.Theme.getColor("action_button_text");
                            }
                        }
                        font: UM.Theme.getFont("action_button")
                        text: preheatUpdateTimer.running ? catalog.i18nc("@button Cancel pre-heating", "Bed Heat Off") : catalog.i18nc("@button", "Bed Off")
                    }
                }
            }

            onClicked:
            {
                if (!preheatUpdateTimer.running)
                {
                    connectedPrinter.preheatBed(0, connectedPrinter.preheatBedTimeout);
                    //preheatUpdateTimer.start();
                    preheatUpdateTimer.update(); //Update once before the first timer is triggered.
                }
                else
                {
                    connectedPrinter.cancelPreheatBed();
                    preheatUpdateTimer.update();
                }
            }

            onHoveredChanged:
            {
                if (hovered)
                {
                    base.showTooltip(
                        base,
                        {x: 0, y: preheatButton.mapToItem(base, 0, 0).y},
                        catalog.i18nc("@tooltip of pre-heat", "Heat the bed in advance before printing. You can continue adjusting your print while it is heating, and you won't have to wait for the bed to heat up when you're ready to print.")
                    );
                }
                else
                {
                    base.hideTooltip();
                }
            }
        }
    }

    UM.SettingPropertyProvider
    {
        id: bedTemperature
        containerStackId: Cura.MachineManager.activeMachineId
        key: "material_bed_temperature"
        watchedProperties: ["value", "minimum_value", "maximum_value", "resolve"]
        storeIndex: 0

        property var resolve: Cura.MachineManager.activeStackId != Cura.MachineManager.activeMachineId ? properties.resolve : "None"
    }

    UM.SettingPropertyProvider
    {
        id: machineExtruderCount
        containerStackId: Cura.MachineManager.activeMachineId
        key: "machine_extruder_count"
        watchedProperties: ["value"]
    }

    Column
    {
        visible: connectedPrinter != null ? connectedPrinter.canControlManually : false
        enabled:
        {
            if (connectedPrinter == null)
            {
                return false; //Can't control the printer if not connected.
            }
            if (!connectedPrinter.acceptsCommands)
            {
                return false; //Not allowed to do anything.
            }
            if (connectedPrinter.jobState == "printing" || connectedPrinter.jobState == "resuming" || connectedPrinter.jobState == "pausing" || connectedPrinter.jobState == "error" || connectedPrinter.jobState == "offline")
            {
                return false; //Printer is in a state where it can't react to manual control
            }
            return true;
        }

        Loader
        {
            sourceComponent: monitorSection
            property string label: catalog.i18nc("@label", "Printer control")
        }

        Row
        {
            width: base.width - 2 * UM.Theme.getSize("default_margin").width
            height: childrenRect.height + UM.Theme.getSize("default_margin").width
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width

            spacing: UM.Theme.getSize("default_margin").width

            Label
            {
                text: catalog.i18nc("@label", "Jog Position")
                color: UM.Theme.getColor("setting_control_text")
                font: UM.Theme.getFont("default")

                width: Math.round(parent.width * 0.4) - UM.Theme.getSize("default_margin").width
                height: UM.Theme.getSize("setting_control").height
                verticalAlignment: Text.AlignVCenter
            }

           Column
            {
                spacing: UM.Theme.getSize("default_lining").height

                Label
                {
                    text: catalog.i18nc("@label", "X")
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_top");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(distancesRow.currentDistance, 0, 0)
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("home");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.homeX()
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_bottom");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(-distancesRow.currentDistance, 0, 0)
                    }
                }
            }

			Column
            {
                spacing: UM.Theme.getSize("default_lining").height

                Label
                {
                    text: catalog.i18nc("@label", "Y")
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_top");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, distancesRow.currentDistance, 0)
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("home");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.homeY()
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_bottom");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, -distancesRow.currentDistance, 0)
                    }
                }
            }


            Column
            {
                spacing: UM.Theme.getSize("default_lining").height

                Label
                {
                    text: catalog.i18nc("@label", "Z")
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_top");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, 0, distancesRow.currentDistance)
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("home");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.homeBed()
                    }
                }

                Button
                {
                    iconSource: UM.Theme.getIcon("arrow_bottom");
                    style: monitorButtonStyle
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, 0, -distancesRow.currentDistance)
                    }
                }
            }
			Column
            {
				spacing: UM.Theme.getSize("default_lining").height
                
				Label
                {
                    text: catalog.i18nc("@label", "")
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Button
                {
                    style: textButtonStyle
					text: "Extrude"
                    width: height * 2.5
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveExtruder(distancesRow.currentDistance)
                    }
                }

                Button
                {
                    style: textButtonStyle
					text: "Retract"
                    width: height * 2.5
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.moveExtruder(-distancesRow.currentDistance)
                    }
                }

                Button
                {
                    style: textButtonStyle
					text: "Home All"
                    width: height * 2.5
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.homeBed()
						connectedPrinter.homeHead()
                    }
                }
            }
			Column
            {
				spacing: UM.Theme.getSize("default_lining").height
                
				Label
                {
                    text: catalog.i18nc("@label", "Nozzle")
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Button
                {
                    style: textButtonStyle
					text: "1"
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.changeTool(0)
            }
        }
		
                Button
                {
                    style: textButtonStyle
					text: "2"
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.changeTool(1)
                    }
                }

				Button
                {
                    style: textButtonStyle
					text: "3"
                    width: height
                    height: UM.Theme.getSize("setting_control").height

                    onClicked:
                    {
                        connectedPrinter.changeTool(2)
                    }
                }
            }
        }

        Row
        {
            id: distancesRow

            width: base.width - 2 * UM.Theme.getSize("default_margin").width
            height: childrenRect.height + UM.Theme.getSize("default_margin").width
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width

            spacing: UM.Theme.getSize("default_margin").width

            property real currentDistance: 10

            Label
            {
                text: catalog.i18nc("@label", "Jog Distance (mm)")
                color: UM.Theme.getColor("setting_control_text")
                font: UM.Theme.getFont("default")

                width: Math.round(parent.width * 0.4) - UM.Theme.getSize("default_margin").width
                height: UM.Theme.getSize("setting_control").height
                verticalAlignment: Text.AlignVCenter
            }

            Row
            {
                Repeater
                {
                    model: distancesModel
                    delegate: Button
                    {
                        height: UM.Theme.getSize("setting_control").height
                        width: height + UM.Theme.getSize("default_margin").width

                        text: model.label
                        exclusiveGroup: distanceGroup
                        checkable: true
                        checked: distancesRow.currentDistance == model.value
                        onClicked: distancesRow.currentDistance = model.value

                        style: ButtonStyle {
                            background: Rectangle {
                                border.width: control.checked ? UM.Theme.getSize("default_lining").width * 2 : UM.Theme.getSize("default_lining").width
                                border.color:
                                {
                                    if(!control.enabled)
                                    {
                                        return UM.Theme.getColor("action_button_disabled_border");
                                    }
                                    else if (control.checked || control.pressed)
                                    {
                                        return UM.Theme.getColor("action_button_active_border");
                                    }
                                    else if(control.hovered)
                                    {
                                        return UM.Theme.getColor("action_button_hovered_border");
                                    }
                                    return UM.Theme.getColor("action_button_border");
                                }
                                color:
                                {
                                    if(!control.enabled)
                                    {
                                        return UM.Theme.getColor("action_button_disabled");
                                    }
                                    else if (control.checked || control.pressed)
                                    {
                                        return UM.Theme.getColor("action_button_active");
                                    }
                                    else if (control.hovered)
                                    {
                                        return UM.Theme.getColor("action_button_hovered");
                                    }
                                    return UM.Theme.getColor("action_button");
                                }
                                Behavior on color { ColorAnimation { duration: 50; } }
                                Label {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: UM.Theme.getSize("default_lining").width * 2
                                    anchors.rightMargin: UM.Theme.getSize("default_lining").width * 2
                                    color:
                                    {
                                        if(!control.enabled)
                                        {
                                            return UM.Theme.getColor("action_button_disabled_text");
                                        }
                                        else if (control.checked || control.pressed)
                                        {
                                            return UM.Theme.getColor("action_button_active_text");
                                        }
                                        else if (control.hovered)
                                        {
                                            return UM.Theme.getColor("action_button_hovered_text");
                                        }
                                        return UM.Theme.getColor("action_button_text");
                                    }
                                    font: UM.Theme.getFont("default")
                                    text: control.text
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideMiddle
                                }
                            }
                            label: Item { }
                        }
                    }
                }
            }
        }

        ListModel
        {
            id: distancesModel
			ListElement { label: "0.02"; value: 0.02}
            ListElement { label: "0.1";  value: 0.1 }
            ListElement { label: "1";    value: 1.0 }
            ListElement { label: "10";   value: 10  }
            ListElement { label: "100";  value: 100 }
        }
        ExclusiveGroup { id: distanceGroup }

		Row
		{
			width: base.width - 2 * UM.Theme.getSize("default_margin").width
            height: childrenRect.height + UM.Theme.getSize("default_margin").width
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width

            spacing: UM.Theme.getSize("default_margin").width

			Label
            {
                text: catalog.i18nc("@label", "Printhead Position")
                color: UM.Theme.getColor("setting_control_text")
                font: UM.Theme.getFont("default")

                width: Math.round(parent.width * 0.4) - UM.Theme.getSize("default_margin").width
                height: UM.Theme.getSize("setting_control").height
                verticalAlignment: Text.AlignVCenter
            }

			Column
            {
				spacing: UM.Theme.getSize("default_lining").height
				visible: true
                
				Label
                {
                    text: connectedPrinter != null ? "X: " + connectedPrinter.headX + " mm" : ""
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

				Label
                {
                    text: connectedPrinter != null ? "Y: " + connectedPrinter.headY + " mm" : ""
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

				Label
                {
                    text: connectedPrinter != null ? "Z: " + connectedPrinter.headZ + " mm" : ""
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                    width: UM.Theme.getSize("section").height
                    height: UM.Theme.getSize("setting_control").height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
			}
		}

		Row
		{
			width: base.width - 2 * UM.Theme.getSize("default_margin").width
            height: childrenRect.height + UM.Theme.getSize("default_margin").width
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width

            spacing: UM.Theme.getSize("default_margin").width

            Label
            {
                text: catalog.i18nc("@label", "Send GCode")
                color: UM.Theme.getColor("setting_control_text")
                font: UM.Theme.getFont("default")

                width: Math.floor(parent.width * 0.4) - UM.Theme.getSize("default_margin").width
                height: UM.Theme.getSize("setting_control").height
                verticalAlignment: Text.AlignVCenter
            }

			TextField
            {
                id: sendingGCode
				font: UM.Theme.getFont("default")
                onAccepted: connectedPrinter.directGCode(text)
            }

			Button
			{
                text: "Enter";
                height: UM.Theme.getSize("setting_control").height
				width: height + UM.Theme.getSize("default_margin").width

				style: textButtonStyle

                onClicked:
                {
                    connectedPrinter.directGCode(sendingGCode.text)
                }
            }
		}
    }


    Loader
    {
        sourceComponent: monitorSection
        property string label: catalog.i18nc("@label", "Active print")
    }
    Loader
    {
        sourceComponent: monitorItem
        property string label: catalog.i18nc("@label", "Job Name")
        property string value: connectedPrinter != null ? connectedPrinter.jobName : ""
    }
    Loader
    {
        sourceComponent: monitorItem
        property string label: catalog.i18nc("@label", "Printing Time")
        property string value: connectedPrinter != null ? getPrettyTime(connectedPrinter.timeTotal) : ""
    }
    Loader
    {
        sourceComponent: monitorItem
        property string label: catalog.i18nc("@label", "Estimated time left")
        property string value: connectedPrinter != null ? getPrettyTime(connectedPrinter.timeTotal - connectedPrinter.timeElapsed) : ""
        visible: connectedPrinter != null && (connectedPrinter.jobState == "printing" || connectedPrinter.jobState == "resuming" || connectedPrinter.jobState == "pausing" || connectedPrinter.jobState == "paused")
    }

    Component
    {
		id: textButtonStyle
		ButtonStyle {
						background: Rectangle {
							color: UM.Theme.getColor("action_button")
							border.width: UM.Theme.getSize("default_lining").width
							border.color: UM.Theme.getColor("action_button_border")
						}
					}
	}

    Component
    {
        id: monitorItem

        Row
        {
            height: UM.Theme.getSize("setting_control").height
            width: Math.round(base.width - 2 * UM.Theme.getSize("default_margin").width)
            anchors.left: parent.left
            anchors.leftMargin: UM.Theme.getSize("default_margin").width

            Label
            {
                width: Math.round(parent.width * 0.4)
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
                font: UM.Theme.getFont("default")
                elide: Text.ElideRight
            }
            Label
            {
                width: Math.round(parent.width * 0.6)
                anchors.verticalCenter: parent.verticalCenter
                text: value
                color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
                font: UM.Theme.getFont("default")
                elide: Text.ElideRight
            }
        }
    }
    Component
    {
        id: monitorSection

        Rectangle
        {
            color: UM.Theme.getColor("setting_category")
            width: base.width
            height: UM.Theme.getSize("section").height

            Label
            {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: UM.Theme.getSize("default_margin").width
                text: label
                font: UM.Theme.getFont("setting_category")
                color: UM.Theme.getColor("setting_category_text")
            }
        }
    }

    Component
    {
        id: monitorButtonStyle

        ButtonStyle
        {
            background: Rectangle
            {
                border.width: UM.Theme.getSize("default_lining").width
                border.color:
                {
                    if(!control.enabled)
                    {
                        return UM.Theme.getColor("action_button_disabled_border");
                    }
                    else if(control.pressed)
                    {
                        return UM.Theme.getColor("action_button_active_border");
                    }
                    else if(control.hovered)
                    {
                        return UM.Theme.getColor("action_button_hovered_border");
                    }
                    return UM.Theme.getColor("action_button_border");
                }
                color:
                {
                    if(!control.enabled)
                    {
                        return UM.Theme.getColor("action_button_disabled");
                    }
                    else if(control.pressed)
                    {
                        return UM.Theme.getColor("action_button_active");
                    }
                    else if(control.hovered)
                    {
                        return UM.Theme.getColor("action_button_hovered");
                    }
                    return UM.Theme.getColor("action_button");
                }
                Behavior on color
                {
                    ColorAnimation
                    {
                        duration: 50
                    }
                }
            }

            label: Item
            {
                UM.RecolorImage
                {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(control.width / 2)
                    height: Math.round(control.height / 2)
                    sourceSize.width: width
                    sourceSize.height: width
                    color:
                    {
                        if(!control.enabled)
                        {
                            return UM.Theme.getColor("action_button_disabled_text");
                        }
                        else if(control.pressed)
                        {
                            return UM.Theme.getColor("action_button_active_text");
                        }
                        else if(control.hovered)
                        {
                            return UM.Theme.getColor("action_button_hovered_text");
                        }
                        return UM.Theme.getColor("action_button_text");
                    }
                    source: control.iconSource
                }
            }
        }
    }
}
