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
        property real sizeOfAreaStep: 32;
        property real areaMode: 0;
        property real areaSize: areaMode * sizeOfAreaStep;
        property bool isPressed: false;
        property bool isFollowed: false;
        property real attackMode: 0;
        property real communicationMode: 0;

        onPressed: (mouse) => {
            isPressed = true;
            if (highlightItem != null) {
                // if there is already a selection, delete it
                highlightItem.destroy();
            }

            var xMouse = mouseX;
            var yMouse = mouseY;

            if (areaMode !== 0) {
                var areaSie = sizeOfAreaStep * areaMode;
                xMouse = mouseX - areaSize / 2;
                if (xMouse < 0) {
                    xMouse = 0;
                }
                yMouse = mouseY - areaSize / 2;
                if (yMouse < 0) {
                    yMouse = 0;
                }
            }

            // create a new rectangle at the wanted position
            highlightItem = highlightComponent.createObject (flyViewVideoMouseArea, {
                "x" : xMouse,
                "y" : yMouse,
            });

            if (areaMode != 0) {
                highlightItem.width = areaSize;
                highlightItem.height = areaSize;
                highlightItem.radius = areaSize;
            } else {
                startX = mouseX;
                startY = mouseY;
            }
        }
        onPositionChanged: (mouse) => {
            if (highlightItem == null || isPressed == false) {
                return;
            }

            if (areaMode != 0) {
                var areaSize = sizeOfAreaStep * areaMode;

                // on move, update the x and y of rectangle
                var xMouse = mouseX - areaSize / 2;
                if (xMouse >= 0) {
                    highlightItem.x = xMouse;
                } else {
                    highlightItem.x = 0;
                }
                var yMouse = mouseY - areaSize / 2;
                if (yMouse >= 0) {
                    highlightItem.y = yMouse;
                } else {
                    highlightItem.y = 0;
                }
            } else {
                // on move, update the width of rectangle

                if (mouseX - startX < 0 ) {
                    highlightItem.x = mouseX;
                } else {
                    highlightItem.x = startX;
                }

                if (mouseY - startY < 0) {
                    highlightItem.y = mouseY;
                } else {
                    highlightItem.y = startY;
                }

                highlightItem.width = Math.abs(mouseX - startX);
                highlightItem.height = Math.abs(mouseY - startY);
            }
        }
        onReleased: {
            if (highlightItem != null) {
                // if there is already a selection, delete it
                highlightItem.destroy();
            }

            if (areaMode != 0) {
                console.log('Send Target Center and Mode to Drone');
                var xMouse = highlightItem.x + areaSize / 2;
                var yMouse = highlightItem.y + areaSize / 2;

                console.log('center x = ' + xMouse);
                console.log('center y = ' + yMouse);
                console.log('mode = ' + areaMode);
                QGroundControl.videoManager.sendTargetMode(flyViewVideoMouseArea.communicationMode, xMouse, yMouse, areaMode, parent.width, parent.height);
            } else {
                if (highlightItem.width == 0 || highlightItem.height == 0) {
                    return;
                }
                console.log('Send Target region to Drone');
                console.log('x = ' + highlightItem.x);
                console.log('y = ' + highlightItem.y);
                console.log('width = ' + highlightItem.width);
                console.log('height = ' + highlightItem.height);
                console.log('maxWidth = ' + parent.width);
                console.log('maxHeight = ' + parent.height);
                QGroundControl.videoManager.sendTarget(flyViewVideoMouseArea.communicationMode, highlightItem.x, highlightItem.y, highlightItem.width, highlightItem.height, parent.width, parent.height);

            }
        }
        Component {
            id: highlightComponent;

            Rectangle {
                color: "#A60000FF"
                border.width: 4
                border.color: "#00F"
            }
        }

        QGCButton {
            id: cancelButton
            visible: pipState.state === pipState.fullState
            // enabled: flyViewVideoMouseArea.isFollowed === true
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
                QGroundControl.videoManager.cancelFollow(flyViewVideoMouseArea.communicationMode);
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
            // enabled: highlightItem && highlightItem.width !== 0 && highlightItem.height !== 0
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
                console.log('Follow Target with attack mode = ' + flyViewVideoMouseArea.attackMode);
                QGroundControl.videoManager.followTarget(flyViewVideoMouseArea.communicationMode, flyViewVideoMouseArea.attackMode);
                flyViewVideoMouseArea.isFollowed = true;

                if (highlightItem != null) {
                    // if there is already a selection, delete it
                    highlightItem.destroy();
                }
            }
        }
        QGCComboBox {
            id: comboAreaSize
            visible: pipState.state === pipState.fullState
            // enabled: flyViewVideoMouseArea.isFollowed === true
            width:          _buttonWidth
            anchors{
                bottom: cancelButton.top
                right: parent.right
                rightMargin: 16
                bottomMargin: 24
            }
            model: [qsTr("Manual"), qsTr("Small"), qsTr("Middle"), qsTr("Big")]

            onActivated: {
                switch (index) {
                case 0:
                    // manual
                    flyViewVideoMouseArea.areaMode = 0;
                    break
                case 1:
                    // small square
                    flyViewVideoMouseArea.areaMode = 1;
                    break
                case 2:
                    // middle square
                    flyViewVideoMouseArea.areaMode = 2;
                    break
                case 3:
                    // big square
                    flyViewVideoMouseArea.areaMode = 3;
                    break
                }
            }

            Component.onCompleted: {
                currentIndex = flyViewVideoMouseArea.areaMode;
            }
        }
        QGCLabel {
            width: _buttonWidth
            anchors{
                bottom: followButton.top
                right: comboAreaSize.left
                rightMargin: 16
                bottomMargin: 24
            }
            text: qsTr("Select Area Mode:")
        }
        QGCComboBox {
            id: comboAttackAreaSize
            visible: pipState.state === pipState.fullState
            // enabled: flyViewVideoMouseArea.isFollowed === true
            width:          _buttonWidth
            anchors{
                bottom: comboAreaSize.top
                right: parent.right
                rightMargin: 16
                bottomMargin: 24
            }
            model: [qsTr("Auto"), qsTr("Fixed"), qsTr("Target"), qsTr("Current")]

            onActivated: {
                switch (index) {
                case 0:
                    // auto
                    flyViewVideoMouseArea.attackMode = 0;
                    break
                case 1:
                    // fixed
                    flyViewVideoMouseArea.attackMode = 1;
                    break
                case 2:
                    // target
                    flyViewVideoMouseArea.attackMode = 2;
                    break
                case 3:
                    // current
                    flyViewVideoMouseArea.attackMode = 3;
                    break
                }
            }

            Component.onCompleted: {
                currentIndex = flyViewVideoMouseArea.attackMode;
            }
        }
        QGCLabel {
            width: _buttonWidth
            anchors{
                bottom: comboAreaSize.top
                right: comboAttackAreaSize.left
                rightMargin: 16
                bottomMargin: 24
            }
            text: qsTr("Select Attack Mode:")
        }
        QGCComboBox {
            id: comboConnectionAreaSize
            visible: pipState.state === pipState.fullState
            // enabled: flyViewVideoMouseArea.isFollowed === true
            width:          _buttonWidth
            anchors{
                bottom: comboAttackAreaSize.top
                right: parent.right
                rightMargin: 16
                bottomMargin: 24
            }
            model: [qsTr("Enabled"), qsTr("Disabled")]

            onActivated: {
                switch (index) {
                case 0:
                    // auto
                    flyViewVideoMouseArea.communicationMode = 0;
                    break
                case 1:
                    // fixed
                    flyViewVideoMouseArea.communicationMode = 1;
                    break
                }
            }

            Component.onCompleted: {
                currentIndex = flyViewVideoMouseArea.communicationMode;
            }
        }
        QGCLabel {
            width: _buttonWidth
            anchors{
                bottom: comboAttackAreaSize.top
                right: comboConnectionAreaSize.left
                rightMargin: 16
                bottomMargin: 24
            }
            text: qsTr("Select Confirmation:")
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
