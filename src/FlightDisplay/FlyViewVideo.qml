/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.12

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ScreenTools   1.0

import QtQuick.Dialogs  1.3

Item {
    id:         _root
    visible:    QGroundControl.videoManager.hasVideo
    property real _buttonWidth:                 ScreenTools.defaultFontPixelWidth * 18
    property Rectangle highlightItem : null;

    property Item pipState: videoPipState
    QGCPipState {
        id:         videoPipState
        pipOverlay: _pipOverlay
        isDark:     true

        onWindowAboutToOpen: {
            QGroundControl.videoManager.stopVideo()
            videoStartDelay.start()
        }

        onWindowAboutToClose: {
            QGroundControl.videoManager.stopVideo()
            videoStartDelay.start()
        }

        onStateChanged: {
            if (pipState.state !== pipState.fullState) {
                QGroundControl.videoManager.fullScreen = false
            }
        }
    }

    Timer {
        id:           videoStartDelay
        interval:     2000;
        running:      false
        repeat:       false
        onTriggered:  QGroundControl.videoManager.startVideo()
    }

    //-- Video Streaming
    FlightDisplayViewVideo {
        id:             videoStreaming
        anchors.fill:   parent
        useSmallFont:   _root.pipState.state !== _root.pipState.fullState
        visible:        QGroundControl.videoManager.isGStreamer
    }
    //-- UVC Video (USB Camera or Video Device)
    Loader {
        id:             cameraLoader
        anchors.fill:   parent
        visible:        !QGroundControl.videoManager.isGStreamer
        source:         QGroundControl.videoManager.uvcEnabled ? "qrc:/qml/FlightDisplayViewUVC.qml" : "qrc:/qml/FlightDisplayViewDummy.qml"
    }

    QGCLabel {
        text: qsTr("Double-click to exit full screen")
        font.pointSize: ScreenTools.largeFontPointSize
        visible: QGroundControl.videoManager.fullScreen && flyViewVideoMouseArea.containsMouse
        anchors.centerIn: parent

        onVisibleChanged: {
            if (visible) {
                labelAnimation.start()
            }
        }

        PropertyAnimation on opacity {
            id: labelAnimation
            duration: 10000
            from: 1.0
            to: 0.0
            easing.type: Easing.InExpo
        }
    }

    MouseArea {
        id: flyViewVideoMouseArea
        anchors.fill:       parent
        enabled:            pipState.state === pipState.fullState
        hoverEnabled: true
        onDoubleClicked:    QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
        property real startX
        property real startY
        property bool isPressed: false;
        property bool isFollowed: false;

        onPressed: (mouse) => {
            isPressed = true;
            if (highlightItem != null) {
                // if there is already a selection, delete it
                highlightItem.destroy();
            }
            // create a new rectangle at the wanted position
            highlightItem = highlightComponent.createObject (flyViewVideoMouseArea, {
                "x" : mouseX,
                "y" : mouseY,
            });
            startX = mouseX;
            startY = mouseY;
        }
        onPositionChanged: (mouse) => {
            if (highlightItem == null || isPressed == false) {
                return;
            }

            // on move, update the width of rectangle

            if (mouseX - startX < 0 ) {
                highlightItem.x = mouseX;
            }

            if (mouseY - startY < 0) {
                highlightItem.y = mouseY;
            }

            highlightItem.width = (Math.abs (mouseX - startX));
            highlightItem.height = (Math.abs (mouseY - startY));
        }
        onReleased: {
            isPressed = false;
            if (highlightItem.width == 0 && highlightItem.height == 0) {
                return;
            }

            console.log('Send Target region to Drone');
            console.log('x = ' + startX);
            console.log('y = ' + startY);
            console.log('width = ' + highlightItem.width);
            console.log('height = ' + highlightItem.height);
            QGroundControl.videoManager.sendTarget(startX, startY, highlightItem.width, highlightItem.height, parent.width, parent.height);
        }
        Component {
            id: highlightComponent;

            Rectangle {
                color: "#0D0080FF"
                border.width: 1
                border.color: "#fff"
            }
        }

        QGCButton {
            id: cancelButton
            visible: pipState.state === pipState.fullState
            enabled: flyViewVideoMouseArea.isFollowed === true
            text:           qsTr("Cancel")
            backRadius:     4
            heightFactor:   0.5
            showBorder:     true
            width:          _buttonWidth
            anchors{
                bottom: parent.bottom
                right: parent.right
                rightMargin: 16
                bottomMargin: 24
            }
            onClicked: {
                console.log('Cancel Follow');
                QGroundControl.videoManager.cancelFollow();
                flyViewVideoMouseArea.isFollowed = false;

                if (highlightItem != null) {
                    // if there is already a selection, delete it
                    highlightItem.destroy();
                }
            }
        }
        QGCButton {
            id: followButton
            visible: pipState.state === pipState.fullState
            enabled: highlightItem && highlightItem.width !== 0 && highlightItem.height !== 0
            text:           qsTr("Follow")
            backRadius:     4
            heightFactor:   0.5
            showBorder:     true
            width:          _buttonWidth
            anchors {
                bottom: parent.bottom
                right: cancelButton.left
                rightMargin: 24
                leftMargin: 16
                bottomMargin: 24
            }
            onClicked: {
                console.log('Follow Target');
                QGroundControl.videoManager.followTarget();
                flyViewVideoMouseArea.isFollowed = true;
            }
        }
    }

    ProximityRadarVideoView{
        anchors.fill:   parent
        vehicle:        QGroundControl.multiVehicleManager.activeVehicle
    }

    ObstacleDistanceOverlayVideo {
        id: obstacleDistance
        showText: pipState.state === pipState.fullState
    }

    Connections {
        target: QGroundControl.videoManager

        function onTargetAreaReceived(startX, startY, width, height) {
            if (highlightItem != null) {
                // if there is already a selection, delete it
                highlightItem.destroy ();
            }
            highlightItem = highlightComponent.createObject (flyViewVideoMouseArea, {
                "x" : startX,
                "y" : startY,
            });
            highlightItem.width = width;
            highlightItem.height = height;
            highlightItem.color = "#0DFF0DFF";
        }
    }
}
