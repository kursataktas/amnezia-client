import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Config"
import "../Components"
import "../Controls2/TextTypes"

PageType {
    id: root

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
    }

    QtObject {
        id: clientLogs

        property string title: qsTr("Client logs")
        property string description: qsTr("AmneziaVPN logs")
        property bool isVisible: true
        property var openLogsHandler: function() {
            SettingsController.openLogsFolder()
        }
        property var exportLogsHandler: function() {
            var fileName = ""
            if (GC.isMobile()) {
                fileName = "AmneziaVPN.log"
            } else {
                fileName = SystemController.getFileName(qsTr("Save"),
                                                        qsTr("Logs files (*.log)"),
                                                        StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/AmneziaVPN",
                                                        true,
                                                        ".log")
            }
            if (fileName !== "") {
                PageController.showBusyIndicator(true)
                SettingsController.exportLogsFile(fileName)
                PageController.showBusyIndicator(false)
                PageController.showNotificationMessage(qsTr("Logs file saved"))
            }
        }
    }

    QtObject {
        id: serviceLogs

        property string title: qsTr("Service logs")
        property string description: qsTr("AmneziaVPN-service logs")
        property bool isVisible: !GC.isMobile()
        property var openLogsHandler: function() {
            SettingsController.openServiceLogsFolder()
        }
        property var exportLogsHandler: function() {
            var fileName = ""
            if (GC.isMobile()) {
                fileName = "AmneziaVPN-service.log"
            } else {
                fileName = SystemController.getFileName(qsTr("Save"),
                                                        qsTr("Logs files (*.log)"),
                                                        StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/AmneziaVPN-service",
                                                        true,
                                                        ".log")
            }
            if (fileName !== "") {
                PageController.showBusyIndicator(true)
                SettingsController.exportServiceLogsFile(fileName)
                PageController.showBusyIndicator(false)
                PageController.showNotificationMessage(qsTr("Logs file saved"))
            }
        }
    }

    property list<QtObject> logTypes: [
        clientLogs,
        serviceLogs
    ]

    ListView {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        property bool isFocusable: true

        Keys.onTabPressed: {
            FocusController.nextKeyTabItem()
        }

        Keys.onBacktabPressed: {
            FocusController.previousKeyTabItem()
        }

        Keys.onUpPressed: {
            FocusController.nextKeyUpItem()
        }

        Keys.onDownPressed: {
            FocusController.nextKeyDownItem()
        }

        Keys.onLeftPressed: {
            FocusController.nextKeyLeftItem()
        }

        Keys.onRightPressed: {
            FocusController.nextKeyRightItem()
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        model: logTypes
        spacing: 24
        snapMode: ListView.SnapOneItem

        reuseItems: true

        clip: true

        header: ColumnLayout {
            id: headerContent

            width: listView.width

            spacing: 0

            HeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Logging")
                descriptionText: qsTr("Enabling this function will save application's logs automatically. " +
                                      "By default, logging functionality is disabled. Enable log saving in case of application malfunction.")
            }

            SwitcherType {
                id: switcher

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Enable logs")

                checked: SettingsController.isLoggingEnabled
                
                onCheckedChanged: {
                    if (checked !== SettingsController.isLoggingEnabled) {
                        SettingsController.isLoggingEnabled = checked
                    }
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: -8

                text: qsTr("Clear logs")
                leftImageSource: "qrc:/images/controls/trash.svg"
                isSmallLeftImage: true

                clickedFunction: function() {
                    var headerText = qsTr("Clear logs?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        PageController.showBusyIndicator(true)
                        SettingsController.clearLogs()
                        PageController.showBusyIndicator(false)
                        PageController.showNotificationMessage(qsTr("Logs have been cleaned up"))
                    }

                    var noButtonFunction = function() {

                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }
        }

        delegate: ColumnLayout {
            id: delegateContent

            width: listView.width

            spacing: 0

            visible: isVisible

            ListItemTitleType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: title
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                color: AmneziaStyle.color.mutedGray

                text: description
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: -8
                Layout.bottomMargin: -8

                text: qsTr("Open logs folder")
                leftImageSource: "qrc:/images/controls/folder-open.svg"
                isSmallLeftImage: true

                clickedFunction: openLogsHandler
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: -8
                Layout.bottomMargin: -8

                text: qsTr("Export logs")
                leftImageSource: "qrc:/images/controls/save.svg"
                isSmallLeftImage: true

                clickedFunction: exportLogsHandler
            }

            DividerType {}
        }
    }
}
