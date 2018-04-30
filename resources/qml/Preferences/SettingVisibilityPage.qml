// Copyright (c) 2016 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.1
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1

import UM 1.2 as UM

import Cura 1.0 as Cura

UM.PreferencesPage
{
    title: catalog.i18nc("@title:tab", "Setting Visibility");

    property int scrollToIndex: 0

    signal scrollToSection( string key )
    onScrollToSection:
    {
        settingsListView.positionViewAtIndex(definitionsModel.getIndex(key), ListView.Beginning)
    }

    function reset()
    {
        UM.Preferences.resetPreference("general/visible_settings")
    }
    resetEnabled: true;

    Item
    {
        id: base;
        anchors.fill: parent;

        CheckBox
        {
            id: toggleVisibleSettings
            anchors
            {
                verticalCenter: filter.verticalCenter;
                left: parent.left;
                leftMargin: UM.Theme.getSize("default_margin").width
            }
            text: catalog.i18nc("@label:textbox", "Check all")
            checkedState:
            {
                if(definitionsModel.visibleCount == definitionsModel.categoryCount)
                {
                    return Qt.Unchecked
                }
                else if(definitionsModel.visibleCount == definitionsModel.rowCount(null))
                {
                    return Qt.Checked
                }
                else
                {
                    return Qt.PartiallyChecked
                }
            }
            partiallyCheckedEnabled: true

            MouseArea
            {
                anchors.fill: parent;
                onClicked:
                {
                    if(parent.checkedState == Qt.Unchecked || parent.checkedState == Qt.PartiallyChecked)
                    {
                        definitionsModel.setAllVisible(true)
                    }
                    else
                    {
                        definitionsModel.setAllVisible(false)
                    }
                }
            }
        }

        TextField
        {
            id: filter;

            anchors
            {
                top: parent.top
                left: toggleVisibleSettings.right
                leftMargin: UM.Theme.getSize("default_margin").width
                right: parent.right
            }

            placeholderText: catalog.i18nc("@label:textbox", "Filter...")

            onTextChanged: definitionsModel.filter = {"i18n_label": "*" + text}
        }

        ScrollView
        {
            id: scrollView

            frameVisible: true

            anchors
            {
                top: filter.bottom;
                topMargin: UM.Theme.getSize("default_margin").height
                left: parent.left;
                right: parent.right;
                bottom: parent.bottom;
            }
            ListView
            {
                id: settingsListView

                model: UM.SettingDefinitionsModel
                {
                    id: definitionsModel
                    containerId: Cura.MachineManager.activeDefinitionId
                    showAll: true
                    exclude: ["speed_wall","speed_wall_0","speed_wall_x","speed_roofing","speed_topbottom","speed_support","settable_per_extruder","speed_support_infill","speed_support_interface","speed_support_roof","speed_support_bottom","speed_prime_tower","speed_travel","speed_layer_0","speed_print_layer_0","speed_travel_layer_0","skirt_brim_speed","max_feedrate_z_override","speed_slowdown_layers","speed_equalize_flow_enabled","speed_equalize_flow_max","acceleration_enabled","acceleration_print","minimum_value_warning","acceleration_infill","acceleration_wall","acceleration_wall_0","acceleration_wall_x","acceleration_roofing","acceleration_topbottom","acceleration_support","acceleration_support_infill","acceleration_support_interface","acceleration_support_roof","acceleration_support_bottom","acceleration_prime_tower","acceleration_travel","acceleration_layer_0","acceleration_print_layer_0","acceleration_travel_layer_0","acceleration_skirt_brim","jerk_enabled","jerk_print","jerk_infill","jerk_wall","jerk_wall_0","jerk_wall_x","jerk_roofing","jerk_topbottom","jerk_support","jerk_support_infill","jerk_support_interface","jerk_support_roof","jerk_support_bottom","jerk_prime_tower","jerk_travel","jerk_layer_0","jerk_print_layer_0","jerk_travel_layer_0","jerk_skirt_brim",
"default_material_print_temperature","material_print_temperature_layer_0","material_initial_print_temperature","material_final_print_temperature","material_extrusion_cool_down_speed","material_bed_temperature_layer_0","material_adhesion_tendency","material_surface_energy","retract_at_layer_change","retraction_amount","retraction_speed","retraction_retract_speed","retraction_prime_speed","retraction_extra_prime_amount","retraction_min_travel","retraction_count_max","retraction_extrusion_window","material_standby_temperature","switch_extruder_retraction_amount","switch_extruder_retraction_speeds","switch_extruder_retraction_speed","switch_extruder_prime_speed",
"line_width","wall_line_width","wall_line_width_0","wall_line_width_x","skin_line_width","infill_line_width","skirt_brim_line_width","support_line_width","support_interface_line_width","support_roof_line_width","support_bottom_line_width","prime_tower_line_width","initial_layer_line_width_factor",
"layer_height_0","machine_settings", "command_line_settings", "shell", "infill","travel","cooling","support","platform_adhesion","experimental","blackmagic","meshfix","dual"]
                    showAncestors: true
                    expanded: ["*"]
                    visibilityHandler: UM.SettingPreferenceVisibilityHandler { }
                }

                delegate: Loader
                {
                    id: loader

                    width: parent.width
                    height: model.type != undefined ? UM.Theme.getSize("section").height : 0

                    property var definition: model
                    property var settingDefinitionsModel: definitionsModel

                    asynchronous: true
                    active: model.type != undefined
                    sourceComponent:
                    {
                        switch(model.type)
                        {
                            case "category":
                                return settingVisibilityCategory
                            default:
                                return settingVisibilityItem
                        }
                    }
                }
            }
        }

        UM.I18nCatalog { name: "cura"; }
        SystemPalette { id: palette; }

        Component
        {
            id: settingVisibilityCategory;

            UM.SettingVisibilityCategory { }
        }

        Component
        {
            id: settingVisibilityItem;

            UM.SettingVisibilityItem { }
        }
    }
}
