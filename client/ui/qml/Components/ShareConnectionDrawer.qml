import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"

DrawerType {
    id: root

    property alias headerText: header.headerText
    property alias configContentHeaderText: configContentHeader.headerText
    property alias contentVisible: content.visible

    property string configExtension: ".vpn"
    property string configCaption: qsTr("Save AmneziaVPN config")
    property string configFileName: "amnezia_config.vpn"

    width: parent.width
    height: parent.height * 0.9

    onClosed: {
        configExtension = ".vpn"
        configCaption = qsTr("Save AmneziaVPN config")
        configFileName = "amnezia_config.vpn"
    }

    Item {
        anchors.fill: parent

        Header2Type {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.leftMargin: 16
            anchors.rightMargin: 16
        }

        FlickableType {
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            contentHeight: content.height + 32

            ColumnLayout {
                id: content

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                anchors.leftMargin: 16
                anchors.rightMargin: 16

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 16

                    text: qsTr("Share")
                    imageSource: "qrc:/images/controls/share-2.svg"

                    onClicked: fileDialog.open()

                    FileDialog {
                        id: fileDialog
                        acceptLabel: configCaption
                        nameFilters: [ "Config files (*" + configExtension + ")" ]
                        fileMode: FileDialog.SaveFile

                        currentFile: StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/" + configFileName
                        defaultSuffix: configExtension
                        onAccepted: {
                            ExportController.saveFile(fileDialog.currentFile.toString())
                        }
                    }
                }

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    defaultColor: "transparent"
                    hoveredColor: Qt.rgba(1, 1, 1, 0.08)
                    pressedColor: Qt.rgba(1, 1, 1, 0.12)
                    disabledColor: "#878B91"
                    textColor: "#D7D8DB"
                    borderWidth: 1

                    text: qsTr("Copy")
                    imageSource: "qrc:/images/controls/copy.svg"

                    onClicked: {
                        configText.selectAll()
                        configText.copy()
                        configText.select(0, 0)
                        PageController.showNotificationMessage(qsTr("Copied"))
                    }
                }

                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    defaultColor: "transparent"
                    hoveredColor: Qt.rgba(1, 1, 1, 0.08)
                    pressedColor: Qt.rgba(1, 1, 1, 0.12)
                    disabledColor: "#878B91"
                    textColor: "#D7D8DB"
                    borderWidth: 1

                    text: qsTr("Show content")

                    onClicked: {
                        configContentDrawer.visible = true
                    }
                }

                DrawerType {
                    id: configContentDrawer

                    width: parent.width
                    height: parent.height * 0.9

                    BackButtonType {
                        id: backButton

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 16

                        backButtonFunction: function() {
                            configContentDrawer.visible = false
                        }
                    }

                    FlickableType {
                        anchors.top: backButton.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        contentHeight: configContent.implicitHeight + configContent.anchors.topMargin + configContent.anchors.bottomMargin

                        ColumnLayout {
                            id: configContent

                            anchors.fill: parent
                            anchors.rightMargin: 16
                            anchors.leftMargin: 16

                            Header2Type {
                                id: configContentHeader
                                Layout.fillWidth: true
                                Layout.topMargin: 16
                            }

                            TextArea {
                                id: configText

                                Layout.fillWidth: true
                                Layout.topMargin: 16
                                Layout.bottomMargin: 16

                                padding: 0
                                leftPadding: 0
                                height: 24

                                color: "#D7D8DB"
                                selectionColor:  "#633303"
                                selectedTextColor: "#D7D8DB"

                                font.pixelSize: 16
                                font.weight: Font.Medium
                                font.family: "PT Root UI VF"

                                text: ExportController.config

                                wrapMode: Text.Wrap

                                background: Rectangle {
                                    color: "transparent"
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    Layout.topMargin: 20

                    visible: ExportController.qrCodesCount > 0

                    color: "white"

                    Image {
                        anchors.fill: parent
                        smooth: false

                        source: ExportController.qrCodesCount ? ExportController.qrCodes[0] : ""

                        Timer {
                            property int index: 0
                            interval: 1000
                            running: ExportController.qrCodesCount > 0
                            repeat: true
                            onTriggered: {
                                if (ExportController.qrCodesCount > 0) {
                                    index++
                                    if (index >= ExportController.qrCodesCount) {
                                        index = 0
                                    }
                                    parent.source = ExportController.qrCodes[index]
                                }
                            }
                        }

                        Behavior on source {
                            PropertyAnimation { duration: 200 }
                        }
                    }
                }

                ParagraphTextType {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.bottomMargin: 32

                    visible: ExportController.qrCodesCount > 0

                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("To read the QR code in the Amnezia app, select \"Add server\" → \"I have data to connect\" → \"QR code, key or settings file\"")
                }
            }
        }
    }
}
