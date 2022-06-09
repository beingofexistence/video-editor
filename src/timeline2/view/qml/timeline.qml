/*
    SPDX-FileCopyrightText: 2017-2021 Jean-Baptiste Mardelle <jb@kdenlive.org>
    SPDX-FileCopyrightText: 2017 Nicolas Carion
    SPDX-FileCopyrightText: 2020 Sashmita Raghav
    SPDX-FileCopyrightText: 2021 Julius Künzel <jk.kdedev@smartlab.uber.space>

    SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick 2.11
import QtQml.Models 2.11
import QtQuick.Controls 2.4
import Kdenlive.Controls 1.0
import 'Timeline.js' as Logic
import com.enums 1.0
import org.kde.kdenlive 1.0 as Kdenlive

Rectangle {
    id: root
    objectName: "timelineview"
    SystemPalette { id: activePalette }
    color: activePalette.window
    property bool debugmode: false
    property bool validMenu: false
    property color textColor: activePalette.text
    property var groupTrimData
    property bool trimInProgress: false
    property bool dragInProgress: dragProxyArea.pressed || dragProxyArea.drag.active || groupTrimData !== undefined || spacerGroup > -1 || trimInProgress
    property int trimmingOffset: 0
    property int trimmingClickFrame: -1

    signal clipClicked()
    signal mousePosChanged(int position)
    signal showClipMenu(int cid)
    signal showCompositionMenu()
    signal showTimelineMenu()
    signal showRulerMenu()
    signal showHeaderMenu()
    signal showTargetMenu(int ix)
    signal zoomIn(bool onMouse)
    signal zoomOut(bool onMouse)
    signal processingDrag(bool dragging)
    signal showSubtitleClipMenu()

    FontMetrics {
        id: fontMetrics
        font: miniFont
    }

    onDragInProgressChanged: {
        processingDrag(!root.dragInProgress)
    }

    function endBinDrag() {
        clipDropArea.processDrop()
    }

    function fitZoom() {
        return scrollView.width / (timeline.duration * 1.1)
    }

    function scrollPos() {
        return scrollView.contentX
    }

    function goToStart(pos) {
        scrollView.contentX = pos
    }

    function switchSubtitleTrack() {
        if (subtitleTrack.height > root.collapsedHeight) {
            subtitleTrack.height = root.collapsedHeight
        } else {
            subtitleTrack.height = 5 * root.baseUnit
        }
    }

    function highlightSub(ix) {
        var currentSub = subtitlesRepeater.itemAt(ix)
        currentSub.editText()
    }

    function checkDeletion(itemId) {
        if (dragProxy.draggedItem === itemId) {
            endDrag()
        }
        if (itemId === mainItemId) {
            mainItemId = -1
        }
    }

    function getActiveTrackStreamPos() {
        // Return the relative y click position, to display the context menu
        return Logic.getTrackYFromId(timeline.activeTrack) + rulercontainer.height - scrollView.contentY
    }

    function updatePalette() {
        root.color = activePalette.window
        root.textColor = activePalette.text
        playhead.fillColor = activePalette.windowText
        ruler.dimmedColor = (activePalette.text.r + activePalette.text.g + activePalette.text.b > 1.5) ? Qt.darker(activePalette.text, 1.3) : Qt.lighter(activePalette.text, 1.3)
        ruler.repaintRuler()
        // Disable caching for track header icons
        root.paletteUnchanged = false
    }

    function moveSelectedTrack(offset) {
        var newTrack
        if (timeline.activeTrack < 0 ) {
            if (offset <0) {
                newTrack = -2
            } else {
                newTrack = max
            }
        } else {
            var cTrack = Logic.getTrackIndexFromId(timeline.activeTrack)
            newTrack = cTrack + offset
        }
        var max = tracksRepeater.count;
        if (newTrack < 0) {
            if (showSubtitles && newTrack === -1) {
                timeline.activeTrack = -2
                return
            }
            newTrack = max - 1;
        } else if (newTrack >= max) {
            if (showSubtitles) {
                timeline.activeTrack = -2
                return
            }
            newTrack = 0;
        }
        timeline.activeTrack = tracksRepeater.itemAt(newTrack).trackInternalId
    }

    function zoomByWheel(wheel) {
        if (wheel.modifiers & Qt.AltModifier) {
            // Seek to next snap
            if (wheel.angleDelta.x > 0) {
                timeline.triggerAction('monitor_seek_snap_backward')
            } else {
                timeline.triggerAction('monitor_seek_snap_forward')
            }
        } else if (wheel.modifiers & Qt.ControlModifier) {
            root.wheelAccumulatedDelta += wheel.angleDelta.y;
            // Zoom
            if (root.wheelAccumulatedDelta >= defaultDeltasPerStep) {
                root.zoomIn(true);
                root.wheelAccumulatedDelta = 0;
            } else if (root.wheelAccumulatedDelta <= -defaultDeltasPerStep) {
                root.zoomOut(true);
                root.wheelAccumulatedDelta = 0;
            }
        } else if (wheel.modifiers & Qt.ShiftModifier) {
            if (scrollVertically || rubberSelect.visible) {
                horizontalScroll(wheel)
            } else {
                verticalScroll(wheel)
            }
        } else {
            if (scrollVertically) {
                verticalScroll(wheel)
            } else {
                horizontalScroll(wheel)
            }
        }
        wheel.accepted = true
    }

    function horizontalScroll(wheel) {
        var initialX = scrollView.contentX
        if (wheel.angleDelta.y < 0) {
            scrollView.contentX = Math.max(0, Math.min(scrollView.contentX - wheel.angleDelta.y, timeline.fullDuration * root.timeScale - scrollView.width))
        } else {
            scrollView.contentX = Math.max(scrollView.contentX - wheel.angleDelta.y, 0)
        }
        if (dragProxyArea.pressed && dragProxy.draggedItem > -1) {
            dragProxy.x += scrollView.contentX - initialX
            dragProxyArea.moveItem()
        } else if (rubberSelect.visible) {
            var newX = tracksArea.mouseX + scrollView.contentX
            if (newX < rubberSelect.originX) {
                rubberSelect.x = newX
                rubberSelect.width = rubberSelect.originX - newX
            } else {
                rubberSelect.x = rubberSelect.originX
                rubberSelect.width = newX - rubberSelect.originX
            }
        }
    }

    function verticalScroll(wheel) {
        if (wheel.angleDelta.y < 0) {
            scrollView.contentY = Math.max(0, Math.min(scrollView.contentY - wheel.angleDelta.y, trackHeaders.height + subtitleTrackHeader.height - tracksArea.height + horZoomBar.height + ruler.height))
        } else {
            scrollView.contentY = Math.max(scrollView.contentY - wheel.angleDelta.y, 0)
        }
    }

    function continuousScrolling(x, y) {
        // This provides continuous scrolling at the left/right edges.
        if (x > scrollView.contentX + scrollView.width - root.baseUnit * 3) {
            scrollTimer.horizontal = root.baseUnit
            scrollTimer.start()
        } else if (x < 50) {
            scrollView.contentX = 0;
            scrollTimer.horizontal = 0
            scrollTimer.stop()
        } else if (x < scrollView.contentX + root.baseUnit * 3) {
            scrollTimer.horizontal = -root.baseUnit
            scrollTimer.start()
        } else {
            if (y > scrollView.contentY + scrollView.height + ruler.height - root.baseUnit) {
                scrollTimer.vertical = root.baseUnit
                scrollTimer.horizontal = 0
                scrollTimer.start()
            } else if (scrollView.contentY > 0 && (y - (scrollView.contentY + ruler.height ) < root.baseUnit)) {
                scrollTimer.vertical = -root.baseUnit
                scrollTimer.horizontal = 0
                scrollTimer.start()
            } else {
                scrollTimer.vertical = 0
                scrollTimer.horizontal = 0
                scrollTimer.stop()
            }
        }
    }

    function getMousePos() {
        if (dragProxy.draggedItem > -1 && dragProxy.masterObject) {
            return (dragProxy.masterObject.x + dragProxy.masterObject.mouseXPos) / root.timeScale
        }
        if (tracksArea.containsMouse) {
            if (subtitleMouseArea.containsMouse) {
                return (subtitleMouseArea.mouseX) / root.timeScale
            } else {
                return (scrollView.contentX + tracksArea.mouseX) / root.timeScale
            }
        } else {
            return -1;
        }
    }
    function getMouseX() {
        if (dragProxy.draggedItem > -1 && dragProxy.masterObject) {
            return (dragProxy.masterObject.x + dragProxy.masterObject.mouseXPos) - scrollView.contentX
        }
        if (tracksArea.containsMouse) {
            return tracksArea.mouseX
        } else {
            return -1;
        }
    }

    function getScrollPos() {
        return scrollView.contentX
    }

    function setScrollPos(pos) {
        return scrollView.contentX = pos
    }

    function getCopiedItemId() {
        return copiedClip
    }

    function getMouseTrack() {
        if (dragProxy.draggedItem > -1 && dragProxy.masterObject) {
            return dragProxy.masterObject.trackId
        }
        return Logic.getTrackIdFromPos(tracksArea.mouseY - ruler.height + scrollView.contentY - subtitleTrack.height)
    }

    function getTrackColor(audio, header) {
        var col = activePalette.alternateBase
        if (audio) {
            col = Qt.tint(col, "#06FF00CC")
        }
        if (header) {
            col = Qt.darker(col, 1.05)
        }
        return col
    }

    function centerViewOnCursor() {
        scrollView.contentX = Math.max(0, root.consumerPosition * root.timeScale - (scrollView.width / 2))
    }

    function clearDropData() {
        clipBeingDroppedId = -1
        droppedPosition = -1
        droppedTrack = -1
        clipDropArea.lastDragUuid = ""
        scrollTimer.running = false
        scrollTimer.stop()
        sameTrackIndicator.visible = false
    }

    function isDragging() {
        return dragInProgress
    }

    function initDrag(itemObject, itemCoord, itemId, itemPos, itemTrack, isComposition) {
        dragProxy.x = itemObject.modelStart * timeScale
        dragProxy.y = itemCoord.y
        dragProxy.width = itemObject.clipDuration * timeScale
        dragProxy.height = itemCoord.height
        dragProxy.masterObject = itemObject
        dragProxy.draggedItem = itemId
        dragProxy.sourceTrack = itemTrack
        dragProxy.sourceFrame = itemPos
        dragProxy.isComposition = isComposition
        dragProxy.verticalOffset = isComposition ? itemObject.displayHeight : 0
    }

    function endDrag() {
        dragProxy.draggedItem = -1
        dragProxy.x = 0
        dragProxy.y = 0
        dragProxy.width = 0
        dragProxy.height = 0
        dragProxy.verticalOffset = 0
    }

    function regainFocus(mousePos) {
        var currentMouseTrack = Logic.getTrackIdFromPos(mousePos.y - ruler.height - subtitleTrack.height + scrollView.contentY)
        // Try to find correct item
        var sourceTrack = Logic.getTrackById(currentMouseTrack)
        var mouseYPos = (mousePos.y - ruler.height + scrollView.contentY) - sourceTrack.y
        var allowComposition = mouseYPos > sourceTrack.height / 2
        var tentativeClip = undefined
        root.mousePosChanged(Math.max(0, Math.floor((mousePos.x - trackHeaders.width + scrollView.contentX) / root.timeScale)))
        if (allowComposition) {
            tentativeClip = getItemAtPos(currentMouseTrack, (mousePos.x - trackHeaders.width + scrollView.contentX), true)
            if (tentativeClip) {
                // Ensure mouse is really over the composition
                if (!tentativeClip.doesContainMouse(root.mapToItem(tentativeClip, mousePos.x, mousePos.y))) {
                    tentativeClip = undefined
                }
            }
        }
        if (!tentativeClip) {
            tentativeClip = getItemAtPos(currentMouseTrack, (mousePos.x - trackHeaders.width + scrollView.contentX), false)
        }

        if (tentativeClip && tentativeClip.clipId && tentativeClip.doesContainMouse(root.mapToItem(tentativeClip, mousePos.x, mousePos.y))) {
            dragProxy.draggedItem = tentativeClip.clipId
            var tk = controller.getItemTrackId(tentativeClip.clipId)
            dragProxy.x = tentativeClip.x
            dragProxy.y = sourceTrack.y + (tentativeClip.isComposition ? tentativeClip.displayHeight : tentativeClip.y)
            //+ Logic.getTrackYFromId(tk)
            dragProxy.width = tentativeClip.width
            dragProxy.height = tentativeClip.itemHeight()
            dragProxy.masterObject = tentativeClip
            dragProxy.sourceTrack = tk
            dragProxy.sourceFrame = tentativeClip.modelStart
            dragProxy.isComposition = tentativeClip.isComposition
            dragProxy.verticalOffset = tentativeClip.isComposition ? tentativeClip.displayHeight : 0
            //console.log('missing item', tentativeClip.clipId, ', COORDS: ', dragProxy.x, 'x', dragProxy.y,'-',dragProxy.width,'x',dragProxy.height, ', TK id: ', tk, ', TKY: ', Logic.getTrackYFromId(tk),' STARTFRM: ', dragProxy.sourceFrame)
        } else {
            console.log('item not found')
            if (dragProxy.draggedItem > -1) {
                endDrag()
            }
        }
    }

    function getAudioTracksCount(){
        var audioCount = 0;
        for (var i = 0; i < trackHeaderRepeater.count; i++) {
            if(trackHeaderRepeater.itemAt(i).isAudio) {
                audioCount++;
            }
        }
        return audioCount;
    }

    function getItemAtPos(tk, posx, compositionWanted) {
        var track = Logic.getTrackById(tk)
        if (track == undefined || track.children == undefined) {
            return undefined
        }
        var container = track.children[0]
        var tentativeClip = undefined
        for (var i = 0 ; i < container.children.length; i++) {
            if (container.children[i].children.length === 0 || container.children[i].children[0].children.length === 0) {
                continue
            }
            tentativeClip = container.children[i].children[0].childAt(posx, compositionWanted ? 5 : 0)
            if (tentativeClip && tentativeClip.clipId && (tentativeClip.isComposition === compositionWanted)) {
                break
            }
        }
        return tentativeClip
    }
    Keys.onDownPressed: {
        root.moveSelectedTrack(1)
    }
    Keys.onUpPressed: {
        root.moveSelectedTrack(-1)
    }
    Keys.onShortcutOverride: event.accepted = focus && event.key === Qt.Key_F2
    Keys.onPressed: {
        if (event.key == Qt.Key_F2) {
            Logic.getTrackHeaderById(timeline.activeTrack).editName()
            event.accepted = true;
        }
    }

    property int activeTool: ProjectTool.SelectTool
    property int baseUnit: Math.max(12, fontMetrics.font.pixelSize)
    property int minClipWidthForViews: 1.5 * baseUnit
    property real fontUnit: fontMetrics.font.pointSize
    property int collapsedHeight: Math.max(28, baseUnit * 1.8)
    property int minHeaderWidth: 6 * collapsedHeight
    property int headerWidth: Math.max(minHeaderWidth, timeline.headerWidth())
    property color selectedTrackColor: Qt.rgba(activePalette.highlight.r, activePalette.highlight.g, activePalette.highlight.b, 0.2)
    property color frameColor: Qt.rgba(activePalette.shadow.r, activePalette.shadow.g, activePalette.shadow.b, 0.5)
    property bool autoScrolling: timeline.autoScroll
    property int duration: timeline.duration
    property color audioColor: timeline.audioColor
    property color videoColor: timeline.videoColor
    property color titleColor: timeline.titleColor
    property color imageColor: timeline.imageColor
    property color slideshowColor: timeline.slideshowColor
    property color lockedColor: timeline.lockedColor
    property color selectionColor: timeline.selectionColor
    property color groupColor: timeline.groupColor
    property color thumbColor1: timeline.thumbColor1
    property color thumbColor2: timeline.thumbColor2
    property int mainItemId: -1
    property int clickFrame: -1
    property int clipBeingDroppedId: -1
    property string clipBeingDroppedData
    property int droppedPosition: -1
    property int droppedTrack: -1
    property int clipBeingMovedId: -1
    property int consumerPosition: proxy.position
    property int spacerGroup: -1
    property int spacerTrack: -1
    property int spacerFrame: -1
    property int finalSpacerFrame: -1
    property int spacerClickFrame: -1
    property bool spacerGuides: false
    property real timeScale: timeline.scaleFactor
    property int snapping: (timeline.snap && (root.timeScale < 2 * baseUnit)) ? Math.floor(baseUnit / (root.timeScale > 3 ? root.timeScale / 2 : root.timeScale)) : -1
    property var timelineSelection: timeline.selection
    property int selectedMix: timeline.selectedMix
    property var selectedGuides: []
    property int trackHeight
    property int copiedClip: -1
    property int zoomOnMouse: -1
    property bool zoomOnBar: false // Whether the scaling was done with the zoombar
    property int viewActiveTrack: timeline.activeTrack
    property int wheelAccumulatedDelta: 0
    readonly property int defaultDeltasPerStep: 120
    property bool seekingFinished : proxy.seekFinished
    property int scrollMin: scrollView.contentX / root.timeScale
    property int scrollMax: scrollMin + scrollView.contentItem.width / root.timeScale
    property double dar: 16/9
    property bool paletteUnchanged: true
    property int maxLabelWidth: 20 * root.baseUnit * Math.sqrt(root.timeScale)
    property bool showSubtitles: false
    property bool subtitlesWarning: timeline.subtitlesWarning
    property bool subtitlesLocked: timeline.subtitlesLocked
    property bool subtitlesDisabled: timeline.subtitlesDisabled
    property int trackTagWidth: fontMetrics.boundingRect("M").width * ((getAudioTracksCount() > 9) || (trackHeaderRepeater.count - getAudioTracksCount() > 9)  ? 3 : 2)
    property bool scrollVertically: timeline.scrollVertically
    property int spacerMinPos: 0

    onSeekingFinishedChanged : {
        playhead.opacity = seekingFinished ? 1 : 0.5
    }

    onShowSubtitlesChanged: {
        subtitleTrack.height = showSubtitles? root.baseUnit * 5 : 0
    }

    //onCurrentTrackChanged: timeline.selection = []

    onTimeScaleChanged: {
        if (scrollView.visibleArea.widthRatio >= 1) {
            scrollView.contentX = 0
            root.zoomOnMouse = -1
        } else if (root.zoomOnMouse >= 0) {
            scrollView.contentX = Math.max(0, root.zoomOnMouse * root.timeScale - getMouseX())
            root.zoomOnMouse = -1
        } else if (root.zoomOnBar) {
            root.zoomOnBar = false
        } else {
            scrollView.contentX = Math.max(0, root.consumerPosition * root.timeScale - (scrollView.width / 2))
        }
        //root.snapping = timeline.snap ? 10 / Math.sqrt(root.timeScale) : -1
        ruler.adjustStepSize()
        if (dragProxy.draggedItem > -1 && dragProxy.masterObject) {
            // update dragged item pos
            dragProxy.masterObject.updateDrag()
        }
    }

    onConsumerPositionChanged: {
        if (root.autoScrolling) Logic.scrollIfNeeded()
    }

    onViewActiveTrackChanged: {
        if (timeline.activeTrack === -2) {
            // subtitle track
            scrollView.contentY = 0
            return
        }
        var tk = Logic.getTrackById(timeline.activeTrack)
        if (tk.y + subtitleTrack.height < scrollView.contentY) {
            scrollView.contentY = Math.max(0, tk.y + subtitleTrack.height)
        } else if (tk.y + tk.height + subtitleTrack.height > scrollView.contentY + scrollView.height) {
            var newY = Math.min(trackHeaders.height + subtitleTrack.height - scrollView.height, tk.y + tk.height - scrollView.height + subtitleTrack.height)
            if (newY >= 0) {
                scrollView.contentY = newY
            }
        }
    }

    onActiveToolChanged: {
        if (root.activeTool === ProjectTool.SpacerTool) {
            // Spacer activated
            endDrag()
        } else if (root.activeTool === ProjectTool.SelectTool) {
            var tk = getMouseTrack()
            if (tk < 0) {
                return
            }
            var pos = getMousePos() * root.timeScale
            var sourceTrack = Logic.getTrackById(tk)
            var allowComposition = tracksArea.mouseY- sourceTrack.y > sourceTrack.height / 2
            var tentativeItem = undefined
            if (allowComposition) {
                tentativeItem = getItemAtPos(tk, pos, true)
            }
            if (!tentativeItem) {
                tentativeItem = getItemAtPos(tk, pos, false)
            }
            if (tentativeItem) {
                tentativeItem.updateDrag()
            }
        }
    }

    DropArea { //Drop area for compositions
        id: compoArea
        width: root.width - headerWidth
        height: root.height - ruler.height
        y: ruler.height
        x: headerWidth
        property bool isAudioDrag
        property int sameCutPos: -1
        keys: 'kdenlive/composition'
        onEntered: {
            if (clipBeingMovedId == -1 && clipBeingDroppedId == -1) {
                var track = Logic.getTrackIdFromPos(drag.y + scrollView.contentY - subtitleTrack.height)
                var frame = Math.round((drag.x + scrollView.contentX) / root.timeScale)
                droppedPosition = frame
                isAudioDrag = drag.getDataAsString('type') == "audio"
                if (track >= 0 && controller.isAudioTrack(track) == isAudioDrag) {
                    clipBeingDroppedData = drag.getDataAsString('kdenlive/composition')
                    clipBeingDroppedId = timeline.insertComposition(track, frame, clipBeingDroppedData, false)
                    continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    drag.acceptProposedAction()
                } else {
                    drag.accepted = false
                }
            }
        }
        onPositionChanged: {
            if (clipBeingMovedId == -1) {
                var track = Logic.getTrackIdFromPos(drag.y + scrollView.contentY - subtitleTrack.height)
                if (track !== -1) {
                    var frame = Math.floor((drag.x + scrollView.contentX) / root.timeScale)
                    if (clipBeingDroppedId >= 0) {
                        if (controller.isAudioTrack(track) != isAudioDrag) {
                            // Don't allow moving composition to an audio track
                            track = controller.getCompositionTrackId(clipBeingDroppedId)
                        }
                        var moveData = controller.suggestCompositionMove(clipBeingDroppedId, track, frame, root.consumerPosition, root.snapping)
                        var currentFrame = moveData[0]
                        var currentTrack = moveData[1]
                        sameCutPos = timeline.isOnCut(clipBeingDroppedId)
                        if (sameCutPos > -1) {
                            var sourceTrack = Logic.getTrackById(currentTrack)
                            if (drag.y < sourceTrack.y + sourceTrack.height / 2 || isAudioDrag) {
                                sameTrackIndicator.x = sameCutPos * root.timeScale - sameTrackIndicator.width / 2
                                sameTrackIndicator.y = sourceTrack.y
                                sameTrackIndicator.height = sourceTrack.height
                                sameTrackIndicator.visible = true
                            } else {
                                sameTrackIndicator.visible = false
                            }
                        } else {
                            sameTrackIndicator.visible = false
                        }

                        continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    } else if (controller.isAudioTrack(track) == isAudioDrag) {
                        frame = controller.suggestSnapPoint(frame, root.snapping)
                        clipBeingDroppedData = drag.getDataAsString('kdenlive/composition')
                        clipBeingDroppedId = timeline.insertComposition(track, frame, clipBeingDroppedData , false)
                        continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    }
                }
            }
            root.mousePosChanged(Math.max(0, Math.floor((drag.x + scrollView.contentX) / root.timeScale)))
        }
        onExited:{
            if (clipBeingDroppedId != -1) {
                // If we exit, remove composition
                controller.requestItemDeletion(clipBeingDroppedId, false)
                clearDropData()
            }
        }
        onDropped: {
            if (clipBeingDroppedId != -1) {
                var frame = controller.getCompositionPosition(clipBeingDroppedId)
                var track = controller.getCompositionTrackId(clipBeingDroppedId)
                // we simulate insertion at the final position so that stored undo has correct value
                controller.requestItemDeletion(clipBeingDroppedId, false)
                if (sameTrackIndicator.visible) {
                    // We want a same track composition
                    timeline.insertNewMix(track, sameCutPos, clipBeingDroppedData)
                } else if (!isAudioDrag) {
                    timeline.insertNewCompositionAtPos(track, frame, clipBeingDroppedData)
                } else {
                    // Cannot insert an audio mix composition
                }
            }
            clearDropData()
            regainFocus(clipDropArea.mapToItem(root, drag.x, drag.y))
        }
    }
    DropArea {
        //Drop area for bin/clips
        id: clipDropArea
        property string lastDragUuid
        /** @brief local helper function to handle the insertion of multiple dragged items */
        function insertAndMaybeGroup(track, frame, droppedData) {
            var binIds = droppedData.split(";")
            if (binIds.length === 0) {
                return -1
            }

            var id = -1
            if (binIds.length === 1) {
                id = timeline.insertClip(timeline.activeTrack, frame, clipBeingDroppedData, false, true, false)
            } else {
                var ids = timeline.insertClips(timeline.activeTrack, frame, binIds, false, true, false)

                // if the clip insertion succeeded, request the clips to be grouped
                if (ids.length > 0) {
                    timeline.selectItems(ids)
                    id = ids[0]
                }
            }
            return id
        }

        property int fakeFrame: -1
        property int fakeTrack: -1
        width: root.width - headerWidth
        height: root.height - ruler.height
        y: ruler.height
        x: headerWidth
        keys: 'kdenlive/producerslist'
        function processDrop()
        {
            // Process the drop event, useful if drop event happens outside of drop area
            if (clipBeingDroppedId != -1) {
                var frame = controller.getClipPosition(clipBeingDroppedId)
                var track = controller.getClipTrackId(clipBeingDroppedId)
                if (!controller.normalEdit()) {
                    frame = fakeFrame
                    track = fakeTrack
                }
                /* We simulate insertion at the final position so that stored undo has correct value
                 * NOTE: even if dropping multiple clips, requesting the deletion of the first one is
                 * enough as internally it will request the group deletion
                 */
                controller.requestItemDeletion(clipBeingDroppedId, false)

                var binIds = clipBeingDroppedData.split(";")
                if (binIds.length == 1) {
                    if (controller.normalEdit()) {
                        timeline.insertClip(track, frame, clipBeingDroppedData, true, true, false)
                    } else {
                        timeline.insertClipZone(clipBeingDroppedData, track, frame)
                    }
                } else {
                    if (controller.normalEdit()) {
                        timeline.insertClips(track, frame, binIds, true, true)
                    } else {
                        // TODO
                        console.log('multiple clips insert/overwrite not supported yet')
                    }
                }
                fakeTrack = -1
                fakeFrame = -1
                clearDropData()
                if (clipDropArea.containsDrag) {
                    regainFocus(clipDropArea.mapToItem(root, drag.x, drag.y))
                }
            }
        }
        onEntered: {
            if (clipBeingDroppedId > -1 && lastDragUuid != drag.getDataAsString('kdenlive/dragid') && timeline.exists(clipBeingDroppedId)) {
                // We are re-entering drop zone with another drag operation, ensure the previous drop operation is complete
                processDrop()
            }
            if (clipBeingMovedId == -1 && clipBeingDroppedId == -1) {
                //var track = Logic.getTrackIdFromPos(drag.y)
                var yOffset = 0
                if (root.showSubtitles) {
                    yOffset = subtitleTrack.height
                }
                var track = Logic.getTrackIndexFromPos(drag.y + scrollView.contentY - yOffset)
                if (track >= 0  && track < tracksRepeater.count) {
                    var frame = Math.round((drag.x + scrollView.contentX) / root.timeScale)
                    droppedPosition = frame
                    timeline.activeTrack = tracksRepeater.itemAt(track).trackInternalId
                    //drag.acceptProposedAction()
                    clipBeingDroppedData = drag.getDataAsString('kdenlive/producerslist')
                    lastDragUuid = drag.getDataAsString('kdenlive/dragid')
                    if (controller.normalEdit()) {
                        clipBeingDroppedId = insertAndMaybeGroup(timeline.activeTrack, frame, clipBeingDroppedData)
                    } else {
                        // we want insert/overwrite mode, make a fake insert at end of timeline, then move to position
                        frame = controller.adjustFrame(frame, timeline.activeTrack)
                        clipBeingDroppedId = insertAndMaybeGroup(timeline.activeTrack, frame, clipBeingDroppedData)
                        if (clipBeingDroppedId > -1) {
                            var moveData = controller.suggestClipMove(clipBeingDroppedId, timeline.activeTrack, frame, root.consumerPosition, root.snapping)
                            fakeFrame = moveData[0]
                            fakeTrack = moveData[1]
                        } else {
                            drag.accepted = false
                        }
                    }
                    continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                } else {
                    drag.accepted = false
                }
            }
        }
        onExited:{
            if (clipBeingDroppedId != -1 && drag.y < drag.x) {
                // If we exit on top, remove clip
                controller.requestItemDeletion(clipBeingDroppedId, false)
                clearDropData()
            } else if (clipBeingDroppedId > -1) {
                // Clip is dropped
                //console.log('Dragging on left side!!!!!!!!!!!!!!!!!!!!!!!!!!!')
                var moveData = controller.suggestClipMove(clipBeingDroppedId, fakeTrack, 0, root.consumerPosition, root.snapping)
                fakeFrame = moveData[0]
                fakeTrack = moveData[1]
                timeline.activeTrack = fakeTrack
            }
        }
        onPositionChanged: {
            if (clipBeingMovedId == -1) {
                var yOffset = 0
                if (root.showSubtitles) {
                    yOffset = subtitleTrack.height
                }
                var track = Logic.getTrackIndexFromPos(drag.y + scrollView.contentY - yOffset)
                if (track >= 0  && track < tracksRepeater.count) {
                    //timeline.activeTrack = tracksRepeater.itemAt(track).trackInternalId
                    var targetTrack = tracksRepeater.itemAt(track).trackInternalId
                    var frame = Math.floor((drag.x + scrollView.contentX) / root.timeScale)
                    if (clipBeingDroppedId > -1) {
                        var moveData = controller.suggestClipMove(clipBeingDroppedId, targetTrack, frame, root.consumerPosition, root.snapping)
                        fakeFrame = moveData[0]
                        fakeTrack = moveData[1]
                        timeline.activeTrack = fakeTrack
                        //controller.requestClipMove(clipBeingDroppedId, timeline.activeTrack, frame, true, false, false)
                        continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    } else {
                        frame = controller.suggestSnapPoint(frame, root.snapping)
                        if (controller.normalEdit()) {
                            timeline.activeTrack = targetTrack
                            clipBeingDroppedId = insertAndMaybeGroup(targetTrack, frame, drag.getDataAsString('kdenlive/producerslist'), false, true)
                        } else {
                            // we want insert/overwrite mode, make a fake insert at end of timeline, then move to position
                            clipBeingDroppedId = insertAndMaybeGroup(targetTrack, timeline.fullDuration, clipBeingDroppedData)
                            if (clipBeingDroppedId > -1) {
                                var moveData = controller.suggestClipMove(clipBeingDroppedId, targetTrack, frame, root.consumerPosition, root.snapping)
                                fakeFrame = moveData[0]
                                fakeTrack = moveData[1]
                                timeline.activeTrack = fakeTrack
                            }
                        }
                        continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    }
                }
            }
            root.mousePosChanged(Math.max(0, Math.floor((drag.x + scrollView.contentX) / root.timeScale)))
        }
        onDropped: {
            processDrop()
        }
    }
    DropArea { //Drop area for urls (direct drop from file manager)
        /** @brief local helper function to handle the insertion of multiple dragged items */
        property int fakeFrame: -1
        property int fakeTrack: -1
        property var droppedUrls: []
        width: root.width - headerWidth
        height: root.height - ruler.height
        y: ruler.height
        x: headerWidth
        keys: 'text/uri-list'
        onEntered: {
            drag.accepted = true
            droppedUrls.length = 0
            for(var i in drag.urls){
                var url = drag.urls[i]
                droppedUrls.push(Qt.resolvedUrl(url))
            }
        }
        onExited:{
            if (clipBeingDroppedId != -1) {
                controller.requestItemDeletion(clipBeingDroppedId, false)
            }
            clearDropData()
        }
        onPositionChanged: {
            if (clipBeingMovedId == -1) {
                var yOffset = 0
                if (root.showSubtitles) {
                    yOffset = subtitleTrack.height
                }
                var track = Logic.getTrackIndexFromPos(drag.y + scrollView.contentY - yOffset)
                if (track >= 0  && track < tracksRepeater.count) {
                    timeline.activeTrack = tracksRepeater.itemAt(track).trackInternalId
                    continuousScrolling(drag.x + scrollView.contentX, drag.y + scrollView.contentY)
                    if (clipBeingDroppedId == -1) {
                        if (controller.normalEdit() == false) {
                            // we want insert/overwrite mode, make a fake insert at end of timeline, then move to position
                            //clipBeingDroppedId = insertAndMaybeGroup(timeline.activeTrack, timeline.fullDuration, clipBeingDroppedData)
                            //fakeFrame = controller.suggestClipMove(clipBeingDroppedId, timeline.activeTrack, frame, root.consumerPosition, Math.floor(root.snapping))
                            fakeTrack = timeline.activeTrack
                        }
                    }
                }
            }
            root.mousePosChanged(Math.max(0, Math.floor((drag.x + scrollView.contentX) / root.timeScale)))
        }
        onDropped: {
            var frame = Math.floor((drag.x + scrollView.contentX) / root.timeScale)
            var track = timeline.activeTrack
            //var binIds = clipBeingDroppedData.split(";")
            //if (binIds.length == 1) {
                if (controller.normalEdit()) {
                    timeline.urlDropped(droppedUrls, frame, track)
                } else {
                    //timeline.insertClipZone(clipBeingDroppedData, track, frame)
                }
            /*} else {
                if (controller.normalEdit()) {
                    timeline.insertClips(track, frame, binIds, true, true)
                } else {
                    // TODO
                    console.log('multiple clips insert/overwrite not supported yet')
                }
            }*/
            clearDropData()
        }
    }

    Row {
        Column {
            id: headerContainer
            width: headerWidth
            z: 1
            Item {
                // Padding between toolbar and track headers.
                width: parent.width
                height: ruler.height
                Button {
                    text: parent.width > metrics.boundingRect.width * 1.4 ? metrics.text : i18nc("Initial for Master", "M")
                    font: miniFont
                    flat: true
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: i18n("Show master effects")
                    TextMetrics {
                        id: metrics
                        text: i18n("Master")
                    }
                    onClicked: {
                        timeline.showMasterEffects()
                    }
                    DropArea { //Drop area for tracks
                        anchors.fill: parent
                        keys: 'kdenlive/effect'
                        property string dropData
                        property string dropSource
                        property int dropRow: -1
                        onEntered: {
                            dropData = drag.getDataAsString('kdenlive/effect')
                            dropSource = drag.getDataAsString('kdenlive/effectsource')
                        }
                        onDropped: {
                            console.log("Add effect: ", dropData)
                            if (dropSource == '') {
                                // drop from effects list
                                controller.addTrackEffect(-1, dropData);
                            } else {
                                controller.copyTrackEffect(-1, dropSource);
                            }
                            dropSource = ''
                            dropRow = -1
                            drag.acceptProposedAction
                        }
                    }
                }
            }
            Flickable {
                // Non-slider scroll area for the track headers.
                id: headerFlick
                contentY: scrollView.contentY
                width: parent.width
                y: ruler.height
                height: root.height - ruler.height
                interactive: false
                clip: true

                MouseArea {
                    width: trackHeaders.width
                    height: trackHeaders.height + subtitleTrackHeader.height
                    acceptedButtons: Qt.NoButton
                    onWheel: {
                        verticalScroll(wheel)
                        wheel.accepted = true
                    }
                }
                Rectangle {
                    id: subtitleTrackHeader
                    width: trackHeaders.width
                    height: subtitleTrack.height
                    property bool collapsed: subtitleTrack.height == root.collapsedHeight
                    visible: height > 0
                    color: (timeline.activeTrack === -2) ? Qt.tint(getTrackColor(false, false), selectedTrackColor) : getTrackColor(false, false)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            timeline.activeTrack = -2
                        }
                    }
                    ToolButton {
                        id: expandSubButton
                        focusPolicy: Qt.NoFocus
                        property var modifier: 0
                        anchors.left: parent.left
                        anchors.leftMargin: 1.5 * root.baseUnit
                        width: root.collapsedHeight
                        height: root.collapsedHeight
                        contentItem: Item {
                            Image {
                                source: subtitleTrackHeader.collapsed ? "image://icon/go-next" : "image://icon/go-down"
                                anchors.centerIn: parent
                                width: root.collapsedHeight - 4
                                height: root.collapsedHeight - 4
                                cache: root.paletteUnchanged
                            }
                        }
                        onClicked: {
                            if (subtitleTrack.height > root.collapsedHeight) {
                                subtitleTrack.height = root.collapsedHeight
                            } else {
                                subtitleTrack.height = 5 * root.baseUnit
                            }
                        }
                    }
                    Label {
                        id: subLabel
                        anchors.left: expandSubButton.left
                        anchors.top: expandSubButton.bottom
                        font: miniFont
                        text: i18n("Subtitles")
                        visible: (subtitleTrackHeader.height > root.collapsedHeight + subLabel.height)
                    }

                    Row {
                        id: subButtonsRow
                        width: childrenRect.width
                        x: Math.max(2 * root.collapsedHeight + 2, parent.width - width - 4)
                        spacing: 0
                        ToolButton {
                            id: warningButton
                            visible: subtitlesWarning
                            focusPolicy: Qt.NoFocus
                            contentItem: Item {
                                Image {
                                    source: "image://icon/data-warning"
                                    anchors.centerIn: parent
                                    width: root.collapsedHeight - 4
                                    height: root.collapsedHeight - 4
                                    cache: root.paletteUnchanged
                                }
                            }
                            width: root.collapsedHeight
                            height: root.collapsedHeight
                            onClicked: timeline.subtitlesWarningDetails()
                            ToolTip {
                                visible: warningButton.hovered
                                font: miniFont
                                delay: 1500
                                timeout: 5000
                                background: Rectangle {
                                    color: activePalette.alternateBase
                                    border.color: activePalette.light
                                }
                                contentItem: Label {
                                    color: activePalette.text
                                    text: i18n("Click to see details")
                                }
                            }
                        }
                        ToolButton {
                            id: analyseButton
                            focusPolicy: Qt.NoFocus
                            contentItem: Item {
                                Image {
                                    source: "image://icon/autocorrection"
                                    anchors.centerIn: parent
                                    width: root.collapsedHeight - 4
                                    height: root.collapsedHeight - 4
                                    cache: root.paletteUnchanged
                                }
                            }
                            width: root.collapsedHeight
                            height: root.collapsedHeight
                            onClicked: timeline.triggerAction('audio_recognition')
                            ToolTip {
                                visible: analyseButton.hovered
                                font: miniFont
                                delay: 1500
                                timeout: 5000
                                background: Rectangle {
                                    color: activePalette.alternateBase
                                    border.color: activePalette.light
                                }
                                contentItem: Label {
                                    color: activePalette.text
                                    text: i18n("Speech recognition")
                                }
                            }
                        }
                        ToolButton {
                            id: muteButton
                            focusPolicy: Qt.NoFocus
                            contentItem: Item {
                                Image {
                                    source: root.subtitlesDisabled ? "image://icon/view-hidden" : "image://icon/view-visible"
                                    anchors.centerIn: parent
                                    width: root.collapsedHeight - 4
                                    height: root.collapsedHeight - 4
                                    cache: root.paletteUnchanged
                                }
                            }
                            width: root.collapsedHeight
                            height: root.collapsedHeight
                            onClicked: timeline.triggerAction('disable_subtitle')
                            ToolTip {
                                visible: muteButton.hovered
                                font: miniFont
                                delay: 1500
                                timeout: 5000
                                background: Rectangle {
                                    color: activePalette.alternateBase
                                    border.color: activePalette.light
                                }
                                contentItem: Label {
                                    color: activePalette.text
                                    text: root.subtitlesDisabled? i18n("Show") : i18n("Hide")
                                }
                            }
                        }

                        ToolButton {
                            id: lockButton
                            width: root.collapsedHeight
                            height: root.collapsedHeight
                            focusPolicy: Qt.NoFocus
                            contentItem: Item {
                                Image {
                                    source: root.subtitlesLocked ? "image://icon/kdenlive-lock" : "image://icon/kdenlive-unlock"
                                    anchors.centerIn: parent
                                    width: root.collapsedHeight - 4
                                    height: root.collapsedHeight - 4
                                    cache: root.paletteUnchanged
                                }
                            }
                            onClicked: timeline.triggerAction('lock_subtitle')
                            ToolTip {
                                visible: lockButton.hovered
                                font: miniFont
                                delay: 1500
                                timeout: 5000
                                background: Rectangle {
                                    color: activePalette.alternateBase
                                    border.color: activePalette.light
                                }
                                contentItem: Label {
                                    color: activePalette.text
                                    text: root.subtitlesLocked? i18n("Unlock track") : i18n("Lock track")
                                }
                            }
                            SequentialAnimation {
                                id: flashLock
                                loops: 1
                                ScaleAnimator {
                                    target: lockButton
                                    from: 1
                                    to: 1.6
                                    duration: 200
                                }
                                ScaleAnimator {
                                    target: lockButton
                                    from: 1.6
                                    to: 1
                                    duration: 200
                                }
                            }
                        }
                    }
                }
                Column {
                    id: trackHeaders
                    y: subtitleTrack.height
                    spacing: 0
                    Repeater {
                        id: trackHeaderRepeater
                        model: multitrack
                        TrackHead {
                            trackName: model.name
                            thumbsFormat: model.thumbsFormat
                            trackTag: model.trackTag
                            isDisabled: model.disabled
                            isComposite: model.composite
                            isLocked: model.locked
                            isActive: model.trackActive
                            isAudio: model.audio
                            showAudioRecord: model.audioRecord
                            effectNames: model.effectNames
                            isStackEnabled: model.isStackEnabled
                            width: headerWidth
                            current: item === timeline.activeTrack
                            trackId: item
                            height: model.trackHeight
                            onIsLockedChanged: tracksRepeater.itemAt(index).isLocked = isLocked
                            collapsed: height <= root.collapsedHeight
                            Component.onCompleted: {
                                root.collapsedHeight = collapsedHeight
                            }
                            onHeightChanged: {
                                collapsed = height <= root.collapsedHeight
                            }
                        }
                    }
                }
                Column {
                    id: trackHeadersResizer
                    spacing: 0
                    width: Math.round(root.baseUnit/3)
                    Rectangle {
                        id: resizer
                        height: trackHeaders.height + subtitleTrackHeader.height
                        width: parent.width
                        x: root.headerWidth - width
                        color: 'red'
                        opacity: 0
                        Drag.active: headerMouseArea.drag.active
                        Drag.proposedAction: Qt.MoveAction

                        MouseArea {
                            id: headerMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor
                            drag.target: parent
                            drag.axis: Drag.XAxis
                            drag.minimumX: root.minHeaderWidth
                            property double startX
                            property double originalX
                            drag.smoothed: false

                            onPressed: {
                                root.autoScrolling = false
                            }
                            onReleased: {
                                root.autoScrolling = timeline.autoScroll
                                parent.opacity = 0
                            }
                            onEntered: parent.opacity = 0.5
                            onExited: parent.opacity = 0
                            onPositionChanged: {
                                if (mouse.buttons === Qt.LeftButton) {
                                    parent.opacity = 0.5
                                    headerWidth = Math.max( root.minHeaderWidth, mapToItem(null, x, y).x + 2)
                                    timeline.setHeaderWidth(headerWidth)
                                }
                            }
                        }
                    }
                }
            }
        }
        MouseArea {
            id: tracksArea
            property real clickX
            property real clickY
            width: root.width - root.headerWidth
            height: root.height
            x: root.headerWidth
            property bool shiftPress: false
            // This provides continuous scrubbing and scimming at the left/right edges.
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.AllButtons
            cursorShape: root.activeTool === ProjectTool.SelectTool ? Qt.ArrowCursor : root.activeTool === ProjectTool.RazorTool ? Qt.IBeamCursor : root.activeTool === ProjectTool.RippleTool ? Qt.SplitHCursor : Qt.SizeHorCursor
            onWheel: {
                if (wheel.modifiers & Qt.AltModifier || wheel.modifiers & Qt.ControlModifier || mouseY > trackHeaders.height) {
                    zoomByWheel(wheel)
                } else if (root.activeTool !== ProjectTool.SlipTool) {
                    var delta = wheel.modifiers & Qt.ShiftModifier ? timeline.fps() : 1
                    proxy.position = wheel.angleDelta.y > 0 ? Math.max(root.consumerPosition - delta, 0) : Math.min(root.consumerPosition + delta, timeline.fullDuration - 1)
                }
            }
            onPressed: {
                focus = true
                shiftPress = (mouse.modifiers & Qt.ShiftModifier) && (mouse.y > ruler.height) && !(mouse.modifiers & Qt.AltModifier)
                if (mouse.buttons === Qt.MidButton || ((root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool) && (mouse.modifiers & Qt.ControlModifier) && !shiftPress)) {
                    clickX = mouseX
                    clickY = mouseY
                    return
                }
                if ((root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool) && shiftPress && mouse.y > ruler.height) {
                        // rubber selection
                        rubberSelect.x = mouse.x + scrollView.contentX
                        rubberSelect.y = mouse.y - ruler.height + scrollView.contentY
                        rubberSelect.clickX = rubberSelect.x
                        rubberSelect.clickY = rubberSelect.y
                        rubberSelect.originX = rubberSelect.clickX
                        rubberSelect.originY = rubberSelect.clickY
                        rubberSelect.width = 0
                        rubberSelect.height = 0
                } else if (mouse.button & Qt.LeftButton) {
                    if (root.activeTool === ProjectTool.RazorTool) {
                        // razor tool
                        var y = mouse.y - ruler.height + scrollView.contentY - subtitleTrack.height
                        if (y >= 0) {
                            timeline.cutClipUnderCursor((scrollView.contentX + mouse.x) / root.timeScale, tracksRepeater.itemAt(Logic.getTrackIndexFromPos(y)).trackInternalId)
                        } else if (subtitleTrack.height > 0) {
                            timeline.cutClipUnderCursor((scrollView.contentX + mouse.x) / root.timeScale, -2)
                        }
                    }
                    if(root.activeTool === ProjectTool.SlipTool) {
                        //slip tool
                        var tk = getMouseTrack()
                        if (tk < 0) {
                            return
                        }
                        var pos = getMousePos() * root.timeScale
                        var sourceTrack = Logic.getTrackById(tk)
                        var mainClip = undefined
                        mainClip = getItemAtPos(tk, pos, false)
                        trimmingClickFrame = Math.round((scrollView.contentX + mouse.x) / root.timeScale)
                        timeline.requestStartTrimmingMode(mainClip.clipId, shiftPress)
                    }
                    if (dragProxy.draggedItem > -1 && mouse.y > ruler.height) {
                        mouse.accepted = false
                        return
                    }
                    if (root.activeTool === ProjectTool.SpacerTool && mouse.y > ruler.height) {
                        // spacer tool
                        var y = mouse.y - ruler.height + scrollView.contentY
                        var frame = (scrollView.contentX + mouse.x) / root.timeScale
                        // Default to all tracks
                        spacerTrack = -1
                        if (mouse.modifiers & Qt.ControlModifier) {
                            if (subtitleTrack.height > 0) {
                                if (y < subtitleTrack.height) {
                                    // Activate spacer on subtitle track only
                                    spacerTrack = -2
                                } else {
                                    spacerTrack = tracksRepeater.itemAt(Logic.getTrackIndexFromPos(y - subtitleTrack.height)).trackInternalId
                                }
                            } else {
                                spacerTrack = tracksRepeater.itemAt(Logic.getTrackIndexFromPos(y)).trackInternalId
                            }
                        }

                        if((mouse.modifiers & Qt.ShiftModifier) || !timeline.guidesLocked) {
                            //spacer tool and shift modifier
                            spacerGuides = true;
                        }

                        spacerGroup = timeline.requestSpacerStartOperation(spacerTrack, frame)
                        spacerMinPos = timeline.spacerMinPos()
                        if (spacerGroup > -1 || spacerGuides) {
                            drag.axis = Drag.XAxis
                            Drag.active = true
                            Drag.proposedAction = Qt.MoveAction
                            spacerClickFrame = frame
                            spacerFrame = spacerGroup > -1 ? controller.getItemPosition(spacerGroup) : frame
                            finalSpacerFrame = spacerFrame
                            if (spacerGuides) {
                                selectedGuides = timeline.spacerSelection(spacerClickFrame)
                                if (selectedGuides.length > 0) {
                                    var firstGuidePos = timeline.getGuidePosition(selectedGuides[0])
                                    if (spacerGroup > -1 && firstGuidePos < spacerFrame) {
                                        // Don't allow moving guide below 0
                                        spacerMinPos = Math.max(spacerMinPos, spacerFrame - firstGuidePos + 1)
                                    }
                                }
                            }
                        }
                    } else if (root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool || mouse.y <= ruler.height) {
                        if (mouse.y > ruler.height) {
                            controller.requestClearSelection();
                            proxy.position = Math.min((scrollView.contentX + mouse.x) / root.timeScale, timeline.fullDuration - 1)
                        } else if (mouse.y > ruler.guideLabelHeight) {
                            proxy.position = Math.min((scrollView.contentX + mouse.x) / root.timeScale, timeline.fullDuration - 1)
                        }

                    }
                } else if (mouse.button & Qt.RightButton) {
                    if (mouse.y > ruler.height) {
                        if (mouse.y > ruler.height + subtitleTrack.height) {
                            timeline.activeTrack = tracksRepeater.itemAt(Logic.getTrackIndexFromPos(mouse.y - ruler.height + scrollView.contentY - subtitleTrack.height)).trackInternalId
                        } else {
                            timeline.activeTrack = -2
                        }
                        root.clickFrame = Math.floor((mouse.x + scrollView.contentX) / root.timeScale)
                        root.showTimelineMenu()
                    } else {
                        // ruler menu
                        proxy.position = (scrollView.contentX + mouse.x) / root.timeScale
                        root.showRulerMenu()
                    }
                }
            }
            property bool scim: false
            onExited: {
                scim = false
                timeline.showTimelineToolInfo(false)
            }
            onEntered: {
                timeline.showTimelineToolInfo(true)
            }
            onDoubleClicked: {
                if (mouse.buttons === Qt.LeftButton && root.showSubtitles && root.activeTool === ProjectTool.SelectTool && mouse.y > ruler.height && mouse.y < (ruler.height + subtitleTrack.height)) {
                    timeline.addSubtitle((scrollView.contentX + mouseX) / root.timeScale)
                } else if (mouse.y < ruler.guideLabelHeight) {
                    timeline.switchGuide((scrollView.contentX + mouseX) / root.timeScale, false)
                }
            }
            onPositionChanged: {
                if (pressed && ((mouse.buttons === Qt.MidButton) || (mouse.buttons === Qt.LeftButton && (root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool) && (mouse.modifiers & Qt.ControlModifier) && !shiftPress))) {
                    // Pan view
                    var newScroll = Math.min(scrollView.contentX - (mouseX - clickX), timeline.fullDuration * root.timeScale - (scrollView.width - scrollView.ScrollBar.vertical.width))
                    var vScroll = Math.min(scrollView.contentY - (mouseY - clickY), trackHeaders.height + subtitleTrackHeader.height - scrollView.height+ horZoomBar.height)
                    scrollView.contentX = Math.max(newScroll, 0)
                    scrollView.contentY = Math.max(vScroll, 0)
                    clickX = mouseX
                    clickY = mouseY
                    return
                }
                if (root.activeTool === ProjectTool.SlipTool && pressed) {
                    var frame = Math.round((mouse.x + scrollView.contentX) / root.timeScale)
                    trimmingOffset = frame - trimmingClickFrame
                    timeline.slipPosChanged(trimmingOffset);
                }
                if (!pressed && !rubberSelect.visible && root.activeTool === ProjectTool.RazorTool) {
                    cutLine.x = Math.floor((scrollView.contentX + mouse.x) / root.timeScale) * root.timeScale - scrollView.contentX
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        // Seek
                        proxy.position = Math.floor((scrollView.contentX + mouse.x) / root.timeScale)
                    }
                }
                root.mousePosChanged(Math.max(0, Math.floor((mouse.x + scrollView.contentX) / root.timeScale)))
                ruler.showZoneLabels = mouse.y < ruler.height
                if (shiftPress && mouse.buttons === Qt.LeftButton && (root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool) && !rubberSelect.visible && rubberSelect.y > 0) {
                    // rubber selection, check if mouse move was enough
                    var dx = rubberSelect.originX - (mouseX + scrollView.contentX)
                    var dy = rubberSelect.originY - (mouseY - ruler.height + scrollView.contentY)
                    if ((Math.abs(dx) + Math.abs(dy)) > Qt.styleHints.startDragDistance) {
                        rubberSelect.visible = true
                    }
                }
                if (rubberSelect.visible) {
                    var newX = mouse.x + scrollView.contentX
                    var newY = mouse.y + scrollView.contentY - ruler.height
                    if (newX < rubberSelect.originX) {
                        rubberSelect.x = newX
                        rubberSelect.width = rubberSelect.originX - newX
                    } else {
                        rubberSelect.x = rubberSelect.originX
                        rubberSelect.width = newX - rubberSelect.originX
                    }
                    if (newY < rubberSelect.originY) {
                        rubberSelect.y = newY
                        rubberSelect.height = rubberSelect.originY - newY
                    } else {
                        rubberSelect.y = rubberSelect.originY
                        rubberSelect.height = newY - rubberSelect.originY
                    }
                    continuousScrolling(newX, newY)
                } else if ((pressedButtons & Qt.LeftButton) && (!shiftPress || spacerGuides)) {
                    if (root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool || (mouse.y < ruler.height && root.activeTool !== ProjectTool.SlipTool)) {
                        proxy.position = Math.max(0, Math.min((scrollView.contentX + mouse.x) / root.timeScale, timeline.fullDuration - 1))
                    } else if (root.activeTool === ProjectTool.SpacerTool && spacerGroup > -1) {
                        // Spacer tool, move group
                        var track = controller.getItemTrackId(spacerGroup)
                        var lastPos = controller.getItemPosition(spacerGroup)
                        var frame = Math.round((mouse.x + scrollView.contentX) / root.timeScale) + spacerFrame - spacerClickFrame
                        frame = Math.max(spacerMinPos, frame)
                        finalSpacerFrame = controller.suggestItemMove(spacerGroup, track, frame, root.consumerPosition, (mouse.modifiers & Qt.ShiftModifier) ? 0 : root.snapping)[0]
                        if (spacerGuides) {
                            timeline.spacerMoveGuides(selectedGuides, finalSpacerFrame - lastPos)
                        }
                        continuousScrolling(mouse.x + scrollView.contentX, mouse.y + scrollView.contentY)
                    } else if (spacerGuides) {
                        var frame = Math.round((mouse.x + scrollView.contentX) / root.timeScale)
                        frame = Math.max(spacerMinPos, frame)
                        timeline.spacerMoveGuides(selectedGuides, frame - spacerFrame)
                        spacerFrame = frame;
                    }

                    scim = true
                } else {
                    scim = false
                }
            }
            onReleased: {
                if((mouse.button & Qt.LeftButton) && root.activeTool === ProjectTool.SlipTool) {
                    // slip tool
                    controller.requestSlipSelection(trimmingOffset, true)
                    trimmingOffset = 0;
                    mouse.accepted = false
                }
                if (rubberSelect.visible) {
                    rubberSelect.visible = false
                    var y = rubberSelect.y
                    var selectSubs = false
                    var selectOnlySubs = false
                    var selectionHeight = rubberSelect.height
                    if (showSubtitles) {
                        selectSubs = y < subtitleTrack.height
                        var bottomRubber = y + rubberSelect.height
                        if (bottomRubber > subtitleTrack.height) {
                            y = Math.max(0, y - subtitleTrack.height)
                            if (selectSubs) {
                                selectionHeight = bottomRubber - subtitleTrack.height
                            }
                        } else {
                            y -= subtitleTrack.height
                            selectOnlySubs = true
                        }
                    }
                    var topTrack = Logic.getTrackIndexFromPos(Math.max(0, y))
                    var bottomTrack = Logic.getTrackIndexFromPos(Math.max(0, y) + selectionHeight)
                    // Check if bottom of rubber selection covers the last track compositions
                    console.log('Got rubber bottom: ', y, ' - height: ', selectionHeight, ', TK y: ', Logic.getTrackYFromId(tracksRepeater.itemAt(bottomTrack).trackInternalId), ', SCROLLVIEWY: ', scrollView.contentY)
                    var selectBottomCompositions = ((y + selectionHeight) - Logic.getTrackYFromId(tracksRepeater.itemAt(bottomTrack).trackInternalId)) > (Logic.getTrackHeightByPos(bottomTrack) * 0.6)
                    if (bottomTrack >= topTrack) {
                        var t = []
                        if (!selectOnlySubs) {
                            for (var i = topTrack; i <= bottomTrack; i++) {
                                t.push(tracksRepeater.itemAt(i).trackInternalId)
                            }
                        }
                        var startFrame = Math.round(rubberSelect.x / root.timeScale)
                        var endFrame = Math.round((rubberSelect.x + rubberSelect.width) / root.timeScale)
                        timeline.selectItems(t, startFrame, endFrame, mouse.modifiers & Qt.ControlModifier, selectBottomCompositions, selectSubs);
                    }
                    rubberSelect.y = -1
                } else if (shiftPress && !spacerGuides) {
                    if (root.activeTool === ProjectTool.RazorTool) {
                        // Shift click, process seek
                        proxy.position = Math.min((scrollView.contentX + mouse.x) / root.timeScale, timeline.fullDuration - 1)
                    } else if (dragProxy.draggedItem > -1) {
                        // Select item
                        if (timeline.selection.indexOf(dragProxy.draggedItem) === -1) {
                            controller.requestAddToSelection(dragProxy.draggedItem)
                        } else {
                            controller.requestRemoveFromSelection(dragProxy.draggedItem)
                        }
                    } else if (!rubberSelect.visible) {
                        // Mouse release with shift press and no rubber select, seek
                        proxy.position = Math.min((scrollView.contentX + mouse.x) / root.timeScale, timeline.fullDuration - 1)
                    }
                    return
                }

                if (spacerGroup > -1 && finalSpacerFrame > -1) {
                    var frame = controller.getItemPosition(spacerGroup)
                    timeline.requestSpacerEndOperation(spacerGroup, spacerFrame, finalSpacerFrame, spacerTrack, selectedGuides, spacerGuides ? spacerClickFrame : -1);
                } else if (spacerGuides) {
                    // Move back guides to original pos
                    timeline.spacerMoveGuides(selectedGuides, spacerClickFrame - spacerFrame)
                    timeline.moveGuidesInRange(spacerClickFrame, -1, spacerFrame - finalSpacerFrame)
                }

                if (spacerGroup > -1 && finalSpacerFrame > -1 || spacerGuides) {
                    spacerClickFrame = -1
                    spacerFrame = -1
                    spacerGroup = -1
                    spacerMinPos = -1
                    selectedGuides = []
                    spacerGuides = false
                }

                scim = false
            }

            Item {
                // Guide zone delimiter
                Rectangle {
                    width: rulercontainer.width
                    height: 1
                    anchors.top: parent.top
                    anchors.topMargin: ruler.guideLabelHeight
                    color: activePalette.dark
                    visible: ruler.guideLabelHeight > 0
                }

                // monitor zone
                Rectangle {
                    width: rulercontainer.width
                    height: 1
                    anchors.top: parent.top
                    anchors.topMargin: ruler.height - ruler.zoneHeight
                    color: activePalette.dark
                    Rectangle {
                        width: rulercontainer.width
                        height: 1
                        anchors.top: parent.bottom
                        color: activePalette.light
                    }
                }
                Flickable {
                    // Non-slider scroll area for the Ruler.
                    id: rulercontainer
                    width: root.width - headerWidth
                    height: Math.round(root.baseUnit * 2.5) + ruler.guideLabelHeight
                    contentX: scrollView.contentX
                    contentWidth: Math.max(parent.width, timeline.fullDuration * timeScale)
                    interactive: false
                    clip: true
                    onWidthChanged: {
                        ruler.adjustStepSize()
                    }
                    Ruler {
                        id: ruler
                        width: rulercontainer.contentWidth
                        height: parent.height
                        TimelinePlayhead {
                            id: playhead
                            height: Math.round(root.baseUnit * .8)
                            width: Math.round(root.baseUnit * 1.2)
                            fillColor: activePalette.windowText
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: ruler.zoneHeight - 1
                            x: cursor.x - (width / 2)
                            // bottom line on zoom
                            Rectangle {
                                color: ruler.dimmedColor
                                width: Math.max(1, root.timeScale)
                                height: 1
                                visible: width > playhead.width
                                x: playhead.width / 2
                                y: playhead.height - 1
                            }
                        }
                        Rectangle {
                            // Vertical line over ruler zone
                            color: root.textColor
                            width: 1
                            height: ruler.zoneHeight - 1
                            x: cursor.x
                            anchors.bottom: parent.bottom
                        }
                    }
                }
                MouseArea {
                    anchors.top: parent.top
                    height: rulercontainer.height
                    width: rulercontainer.width
                    acceptedButtons: Qt.NoButton
                    cursorShape: ruler.cursorShape
                }

                Item {
                    id: baseContainer
                    width: root.width - headerWidth
                    height: root.height - ruler.height
                    y: ruler.height
                    clip: true
                    // These make the striped background for the tracks.
                    // It is important that these are not part of the track visual hierarchy;
                    // otherwise, the clips will be obscured by the Track's background.
                    Rectangle {
                        width: scrollView.width
                        border.width: 1
                        border.color: root.frameColor
                        height: subtitleTrack.height
                        color: (timeline.activeTrack === -2) ? Qt.tint(getTrackColor(false, false), selectedTrackColor) : getTrackColor(false, false)
                    }
                    Column {
                        y: subtitleTrack.height
                        topPadding: -scrollView.contentY
                        Repeater {
                            model: multitrack
                            id: trackBaseRepeater
                            delegate: Rectangle {
                                width: scrollView.width
                                border.width: 1
                                border.color: root.frameColor
                                height: model.trackHeight
                                color: (model.item === timeline.activeTrack) ? Qt.tint(getTrackColor(model.audio, false), selectedTrackColor) : getTrackColor(model.audio, false)
                            }
                        }
                    }
                    Flickable {
                        id: scrollView
                        anchors.fill: parent
                        anchors.rightMargin: vertScroll.visible ? vertScroll.width : 0
                        anchors.bottomMargin: horZoomBar.visible ? horZoomBar.height : 0
                        // Click and drag should seek, not scroll the timeline view
                        //flickableItem.interactive: false
                        clip: true
                        interactive: false
                        /*
                         // Replaced by our custom ZoomBar
                         ScrollBar.horizontal: ScrollBar {
                            id: horScroll
                            parent: scrollView.parent
                            anchors.top: scrollView.top
                            anchors.left: scrollView.left
                            anchors.right: scrollView.right
                        }*/
                        ScrollBar.vertical: ScrollBar {
                            id: vertScroll
                            parent: scrollView.parent
                            anchors.top: scrollView.top
                            anchors.left: scrollView.right
                            anchors.bottom: scrollView.bottom
                        }
                        contentWidth: tracksContainerArea.width
                        contentHeight: tracksContainerArea.height
                        Item {
                            id: subtitleTrack
                            width: tracksContainerArea.width
                            height: 0
                            MouseArea {
                                id: subtitleMouseArea
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                hoverEnabled: true
                                onWheel: zoomByWheel(wheel)
                                onEntered: {
                                    if (root.activeTool === ProjectTool.SelectTool) {
                                        timeline.showKeyBinding(i18n("<b>Double click</b> to add a subtitle"))
                                    }
                                }
                                onPositionChanged: {
                                    tracksArea.positionChanged(mouse)
                                }
                                onExited: {
                                    timeline.showKeyBinding()
                                }
                            }

                            Repeater { id: subtitlesRepeater; model: subtitleDelegateModel }
                        }
                        Item {
                            id: tracksContainerArea
                            width: Math.max(scrollView.width - vertScroll.width, timeline.fullDuration * timeScale)
                            height: trackHeaders.height + subtitleTrackHeader.height
                            y: subtitleTrack.height
                            //Math.max(trackHeaders.height, scrollView.contentHeight - scrollView.__horizontalScrollBar.height)
                            //color: root.color
                            Item {
                                // Drag proxy, responsible for clip / composition move
                                id: dragProxy
                                x: 0
                                y: 0
                                width: 0
                                height: 0
                                property int draggedItem: -1
                                property int sourceTrack
                                property int sourceFrame
                                property bool isComposition
                                property int verticalOffset
                                property var masterObject
                                // opacity: 0.8
                                MouseArea {
                                    id: dragProxyArea
                                    anchors.fill: parent
                                    drag.target: parent
                                    drag.axis: Drag.XAxis
                                    drag.smoothed: false
                                    drag.minimumX: 0
                                    property int dragFrame
                                    property int snapping: root.snapping
                                    property bool moveMirrorTracks: true
                                    cursorShape: root.activeTool === ProjectTool.SelectTool ? dragProxyArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor : tracksArea.cursorShape
                                    enabled: root.activeTool === ProjectTool.SelectTool || root.activeTool === ProjectTool.RippleTool
                                    onPressed: {
                                        if (mouse.modifiers & Qt.ControlModifier || (mouse.modifiers & Qt.ShiftModifier && !(mouse.modifiers & Qt.AltModifier))) {
                                            mouse.accepted = false
                                            return
                                        }
                                        if (!timeline.exists(dragProxy.draggedItem)) {
                                            endDrag()
                                            mouse.accepted = false
                                            return
                                        }
                                        dragFrame = -1
                                        moveMirrorTracks = !(mouse.modifiers & Qt.MetaModifier) && (Qt.platform.os != "windows" || !(mouse.modifiers & Qt.AltModifier))
                                        timeline.activeTrack = dragProxy.sourceTrack
                                        if (timeline.selection.indexOf(dragProxy.draggedItem) === -1) {
                                            controller.requestAddToSelection(dragProxy.draggedItem, /*clear=*/ true)
                                        }
                                        timeline.showAsset(dragProxy.draggedItem)
                                        root.autoScrolling = false
                                        clipBeingMovedId = dragProxy.draggedItem
                                        if (dragProxy.draggedItem > -1) {
                                            var tk = controller.getItemTrackId(dragProxy.draggedItem)
                                            var x = controller.getItemPosition(dragProxy.draggedItem)
                                            var posx = Math.round((parent.x)/ root.timeScale)
                                            var clickAccepted = true
                                            var currentMouseTrack = Logic.getTrackIdFromPos(parent.y)
                                            if (controller.normalEdit() && (tk !== currentMouseTrack || x !== posx)) {
                                                console.log('incorrect drag, Trying to recover item', parent.y,'xpos',x,'=',posx,'track',tk)
                                                // Try to find correct item
                                                var tentativeClip = getItemAtPos(currentMouseTrack, mouseX + parent.x, dragProxy.isComposition)
                                                if (tentativeClip && tentativeClip.clipId) {
                                                    console.log('missing item', tentativeClip.clipId)
                                                    clickAccepted = true
                                                    dragProxy.draggedItem = tentativeClip.clipId
                                                    dragProxy.x = tentativeClip.x
                                                    dragProxy.y = currentMouseTrack.y + tentativeClip.isComposition ? tentativeClip.displayHeight : tentativeClip.y
                                                    dragProxy.height = tentativeClip.itemHeight()
                                                    dragProxy.width = tentativeClip.width
                                                    dragProxy.masterObject = tentativeClip
                                                    dragProxy.sourceTrack = tk
                                                    dragProxy.isComposition = tentativeClip.isComposition
                                                    dragProxy.verticalOffset = tentativeClip.isComposition ? tentativeClip.displayHeight : 0
                                                } else {
                                                    console.log('item not found')
                                                    clickAccepted = false
                                                    mouse.accepted = false
                                                    dragProxy.draggedItem = -1
                                                    dragProxy.masterObject = undefined
                                                    dragProxy.sourceFrame = -1
                                                    parent.x = 0
                                                    parent.y = 0
                                                    parent.width = 0
                                                    parent.height = 0
                                                }
                                            }
                                            if (clickAccepted && dragProxy.draggedItem != -1) {
                                                focus = true;
                                                root.mainItemId = dragProxy.draggedItem
                                                dragProxy.masterObject.originalX = dragProxy.masterObject.x
                                                dragProxy.masterObject.originalTrackId = dragProxy.masterObject.trackId
                                                dragProxy.sourceFrame = dragProxy.masterObject.modelStart
                                                dragProxy.masterObject.forceActiveFocus();
                                            } else {
                                                root.mainItemId = -1
                                            }
                                        } else {
                                            mouse.accepted = false
                                            parent.x = 0
                                            parent.y = 0
                                            parent.width = 0
                                            parent.height = 0
                                        }
                                    }
                                    onPositionChanged: {
                                        // we have to check item validity in the controller, because they could have been deleted since the beginning of the drag
                                        if (dragProxy.draggedItem > -1 && !timeline.exists(dragProxy.draggedItem)) {
                                            endDrag()
                                            return
                                        }
                                        if (dragProxy.draggedItem > -1 && mouse.buttons === Qt.LeftButton &&  (controller.isClip(dragProxy.draggedItem) || controller.isComposition(dragProxy.draggedItem))) {
                                            continuousScrolling(mouse.x + parent.x, dragProxyArea.mouseY + parent.y - dragProxy.verticalOffset + ruler.height + subtitleTrack.height)
                                            snapping = (mouse.modifiers & Qt.ShiftModifier) ? 0 : root.snapping
                                            moveItem()
                                        }
                                    }

                                    function moveItem() {
                                        if (dragProxy.draggedItem > -1) {
                                            var mapped = Math.max(0, tracksContainerArea.mapFromItem(dragProxy, dragProxyArea.mouseX, 0).x)
                                            root.mousePosChanged(Math.floor(mapped / root.timeScale))
                                            var posx = Math.round((parent.x)/ root.timeScale)
                                            var posy = Math.min(Math.max(0, dragProxyArea.mouseY + parent.y - dragProxy.verticalOffset), tracksContainerArea.height)
                                            var tId = Logic.getTrackIdFromPos(posy)
                                            if (dragProxy.masterObject && tId === dragProxy.masterObject.trackId) {
                                                if (posx == dragFrame && controller.normalEdit()) {
                                                    return
                                                }
                                            }
                                            if (dragProxy.isComposition) {
                                                var moveData = controller.suggestCompositionMove(dragProxy.draggedItem, tId, posx, root.consumerPosition, dragProxyArea.snapping)
                                                dragFrame = moveData[0]
                                                timeline.activeTrack = moveData[1]
                                            } else {
                                                if (!controller.normalEdit() && dragProxy.masterObject.parent !== dragContainer) {
                                                    var pos = dragProxy.masterObject.mapToGlobal(dragProxy.masterObject.x, dragProxy.masterObject.y)
                                                    dragProxy.masterObject.parent = dragContainer
                                                    pos = dragProxy.masterObject.mapFromGlobal(pos.x, pos.y)
                                                    dragProxy.masterObject.x = pos.x
                                                    dragProxy.masterObject.y = pos.y
                                                }
                                                var moveData = controller.suggestClipMove(dragProxy.draggedItem, tId, posx, root.consumerPosition, dragProxyArea.snapping, moveMirrorTracks)
                                                dragFrame = moveData[0]
                                                timeline.activeTrack = moveData[1]
                                                //timeline.getItemMovingTrack(dragProxy.draggedItem)
                                            }
                                            var delta = dragFrame - dragProxy.sourceFrame
                                            if (delta != 0) {
                                                var s = timeline.simplifiedTC(Math.abs(delta))
                                                s = i18n("Offset: %1, Position: %2", (delta < 0 ? '-' : '+') + s, timeline.simplifiedTC(dragFrame))
                                                timeline.showToolTip(s);
                                                /*bubbleHelp.show(parent.x + mouseX, Math.max(ruler.height, Logic.getTrackYFromId(timeline.activeTrack)), s)*/
                                            } else {
                                                timeline.showToolTip()
                                                //bubbleHelp.hide()
                                            }
                                        }
                                    }
                                    onReleased: {
                                        clipBeingMovedId = -1
                                        root.autoScrolling = timeline.autoScroll
                                        if (dragProxy.draggedItem > -1 && dragFrame > -1 && (controller.isClip(dragProxy.draggedItem) || controller.isComposition(dragProxy.draggedItem))) {
                                            var tId = controller.getItemTrackId(dragProxy.draggedItem)
                                            if (dragProxy.isComposition) {
                                                controller.requestCompositionMove(dragProxy.draggedItem, dragProxy.sourceTrack, dragProxy.sourceFrame, true, false, false)
                                                controller.requestCompositionMove(dragProxy.draggedItem, tId, dragFrame , true, true, true)
                                            } else {
                                                if (controller.normalEdit()) {
                                                    // Move clip back to original position
                                                    controller.requestClipMove(dragProxy.draggedItem, dragProxy.sourceTrack, dragProxy.sourceFrame, moveMirrorTracks, true, false, false, true)
                                                    // Move clip to final pos
                                                    controller.requestClipMove(dragProxy.draggedItem, tId, dragFrame , moveMirrorTracks, true, true, true)
                                                } else {
                                                    // Fake move, only process final move
                                                    timeline.endFakeMove(dragProxy.draggedItem, dragFrame, true, true, true)
                                                }
                                            }
                                            if (dragProxy.masterObject && dragProxy.masterObject.isGrabbed) {
                                                dragProxy.masterObject.grabItem()
                                            }
                                            dragProxy.x = controller.getItemPosition(dragProxy.draggedItem) * root.timeScale
                                            timeline.showToolTip()
                                            //bubbleHelp.hide()
                                            tracksArea.focus = true
                                            if (!dragProxyArea.containsMouse) {
                                                regainFocus(dragProxyArea.mapToItem(root,mouseX, mouseY))
                                            }
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (dragProxy.masterObject.keyframeModel && dragProxy.masterObject.showKeyframes) {
                                            var newVal = (dragProxy.height - mouseY) / dragProxy.height
                                            var newPos = Math.round(mouseX / timeScale) + dragProxy.masterObject.inPoint
                                            timeline.addEffectKeyframe(dragProxy.draggedItem, newPos, newVal)
                                        } else {
                                            clipBeingMovedId = -1
                                            timeline.ungrabHack()
                                            if(dragProxy.masterObject.itemType === ProducerType.Text || dragProxy.masterObject.itemType === ProducerType.TextTemplate) {
                                                timeline.editTitleClip(dragProxy.draggedItem)
                                            } else {
                                                timeline.editItemDuration(dragProxy.draggedItem)
                                            }
                                        }
                                    }
                                    onClicked: {
                                        if (dragProxy.masterObject.keyframeModel && dragProxy.masterObject.showKeyframes) {
                                            dragProxy.masterObject.resetSelection()
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: zoomByWheel(wheel)
                                cursorShape: dragProxyArea.drag.active ? Qt.ClosedHandCursor : tracksArea.cursorShape
                            }
                            Column {
                                id: tracksContainer
                                Repeater { id: tracksRepeater; model: trackDelegateModel }
                                Item {
                                    id: dragContainer
                                    z: 100
                                }
                            }
                            Rectangle {
                                id: sameTrackIndicator
                                color: 'red'
                                opacity: 0.5
                                visible: false
                                width: root.baseUnit
                                height: width
                            }
                        }
                        Rectangle {
                            id: rubberSelect
                            // Used to determine if drag start should trigger an event
                            property int originX
                            // Used to determine if drag start should trigger an event
                            property int originY
                            // Absolute position of the click event
                            property int clickX
                            property int clickY
                            y: -1
                            color: Qt.rgba(activePalette.highlight.r, activePalette.highlight.g, activePalette.highlight.b, 0.4)
                            border.color: activePalette.highlight
                            border.width: 1
                            visible: false
                        }
                        Repeater { id: guidesRepeater;
                            model: guidesDelegateModel
                        }
                        Rectangle {
                            id: cursor
                            visible: root.consumerPosition > -1
                            color: root.textColor
                            width: 1
                            opacity: 1
                            height: tracksContainerArea.height
                            x: root.consumerPosition * root.timeScale
                        }
                    }
                    Kdenlive.ZoomBar {
                        id: horZoomBar
                        visible: scrollView.visibleArea.widthRatio < 1
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: scrollView.bottom
                        }
                        height: Math.round(root.baseUnit * 0.7)
                        barMinWidth: root.baseUnit
                        fitsZoom: timeline.scaleFactor === root.fitZoom() && root.scrollPos() === 0
                        zoomFactor: scrollView.visibleArea.widthRatio
                        onProposeZoomFactor: {
                            timeline.scaleFactor = scrollView.width / Math.round(proposedValue * scrollView.contentWidth / root.timeScale)
                            zoomOnBar = true
                        }
                        contentPos: scrollView.contentX / scrollView.contentWidth
                        onProposeContentPos: scrollView.contentX = Math.max(0, proposedValue * scrollView.contentWidth)
                        onZoomByWheel: root.zoomByWheel(wheel)
                        onFitZoom: {
                            timeline.scaleFactor = root.fitZoom()
                            scrollView.contentX = 0
                            zoomOnBar = true
                        }
                    }
                }
            }
            Rectangle {
                id: cutLine
                visible: root.activeTool === ProjectTool.RazorTool && (tracksArea.mouseY > ruler.height || subtitleMouseArea.containsMouse)
                color: 'red'
                width: 1
                opacity: 1
                height: tracksContainerArea.height
                x: 0
                //x: root.consumerPosition * root.timeScale - scrollView.contentX
                y: ruler.height
                Rectangle {
                    color: 'red'
                    width: Math.max(0, 1 * root.timeScale - 1)
                    visible: width > 1
                    opacity: 0.2
                    anchors.left:parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
            }
            Rectangle {
                id: multicamLine
                visible: root.activeTool === ProjectTool.MulticamTool && timeline.multicamIn > -1
                color: 'purple'
                width: 3
                opacity: 1
                height: tracksContainerArea.height
                x: timeline.multicamIn * root.timeScale - scrollView.contentX
                y: ruler.height
                Rectangle {
                    // multicam in label
                    width: multilabel.contentWidth + 4
                    height: multilabel.contentHeight + 2
                    radius: height / 4
                    color: 'purple'
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    Text {
                        id: multilabel
                        text: i18n("Multicam In")
                        bottomPadding: 2
                        leftPadding: 2
                        rightPadding: 2
                        font: miniFont
                        color: '#FFF'
                    }
                }
            }
        }
    }

    Rectangle {
        id: bubbleHelp
        property alias text: bubbleHelpLabel.text
        color: root.color //application.toolTipBaseColor
        width: bubbleHelpLabel.width + 6
        height: bubbleHelpLabel.height + 6
        radius: 3
        states: [
            State { name: 'invisible'; PropertyChanges { target: bubbleHelp; opacity: 0} },
            State { name: 'visible'; PropertyChanges { target: bubbleHelp; opacity: 0.8} }
        ]
        state: 'invisible'
        transitions: [
            Transition {
                from: 'invisible'
                to: 'visible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: 'visible'
                to: 'invisible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            }
        ]
        Label {
            id: bubbleHelpLabel
            color: activePalette.text //application.toolTipTextColor
            anchors.centerIn: parent
            font: miniFont
        }
        function show(x, y, text) {
            bubbleHelp.text = text
            bubbleHelp.x = x + tracksArea.x - scrollView.contentX - bubbleHelp.width
            bubbleHelp.y = y + tracksArea.y - scrollView.contentY - bubbleHelp.height + ruler.height - 3
            if (bubbleHelp.state !== 'visible')
                bubbleHelp.state = 'visible'
        }
        function hide() {
            bubbleHelp.state = 'invisible'
            bubbleHelp.opacity = 0
        }
    }
    /*DropShadow {
        source: bubbleHelp
        anchors.fill: bubbleHelp
        opacity: bubbleHelp.opacity
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8
        color: '#80000000'
        transparentBorder: true
        fast: true
    }*/

    DelegateModel {
        id: trackDelegateModel
        model: multitrack
        delegate: Track {
            trackModel: multitrack
            rootIndex: trackDelegateModel.modelIndex(index)
            width: tracksContainerArea.width
            height: trackHeight
            isAudio: audio
            trackThumbsFormat: thumbsFormat
            trackInternalId: item
            effectZones: model.effectZones
            z: tracksRepeater.count - index
        }
    }


    DelegateModel {
        id: guidesDelegateModel
        model: guidesModel
        Item {
            id: guideRoot
            z: 20
            Rectangle {
                id: guideBase
                width: 1
                height: tracksContainerArea.height
                x: model.frame * root.timeScale;
                color: model.color
            }
        }
    }


    DelegateModel {
        id: subtitleDelegateModel
        model: subtitleModel
        delegate: SubTitle {
            subId: model.id
            selected: model.selected
            startFrame: model.startframe
            endFrame: model.endframe
            subtitle: model.subtitle
            isGrabbed: model.grabbed
        }
    }

    Connections {
        target: timeline
        // This connection type is deprecated in Qt >= 5.15, switch to function onFrameFormatChanged() {} once
        // we require Qt >= 5.15
        onFrameFormatChanged: {
            ruler.adjustFormat()
        }
        onSelectionChanged: {
            if (dragProxy.draggedItem > -1 && !timeline.exists(dragProxy.draggedItem)) {
                endDrag()
            }
        }
    }

    // This provides continuous scrolling at the left/right edges.
    Timer {
        id: scrollTimer
        interval: 80
        repeat: true
        triggeredOnStart: true
        property int horizontal: 0
        property int vertical: 0
        onTriggered: {
            if (vertical != 0) {
                scrollView.contentY += vertical
                if (scrollView.contentY <= 0) {
                    scrollView.contentY = 0
                    vertical = 0
                    stop()
                } else {
                    if ((clipBeingMovedId == -1 && !rubberSelect.visible)) {
                        vertical = 0
                        stop()
                    } else {
                        var maxScroll = trackHeaders.height - tracksArea.height + horZoomBar.height + ruler.height + subtitleTrack.height
                        if (scrollView.contentY > maxScroll) {
                            scrollView.contentY = Math.max(0, maxScroll)
                            vertical = 0
                            stop()
                        }
                    }
                }
            }
            if (horizontal != 0) {
                if (scrollView.contentX < -horizontal) {
                    horizontal = - scrollView.contentX
                    scrollView.contentX = 0
                } else {
                    scrollView.contentX += horizontal
                }
                if (dragProxy.draggedItem > -1) {
                    dragProxy.x += horizontal
                    dragProxyArea.moveItem()
                }
                if (scrollView.contentX == 0 || (clipBeingMovedId == -1 && !rubberSelect.visible)) {
                    horizontal = 0
                    stop()
                }
            }
            if (rubberSelect.visible) {
                if (horizontal != 0) {
                    if (rubberSelect.x < rubberSelect.originX) {
                        if (horizontal < 0) {
                            // Expanding left
                            rubberSelect.x += horizontal
                            rubberSelect.width -= horizontal
                        } else if (horizontal < rubberSelect.width) {
                            // Expanding right
                            rubberSelect.x -= horizontal
                            rubberSelect.width -= horizontal
                        } else {
                            // Switching direction
                            rubberSelect.width = rubberSelect.x + rubberSelect.width + horizontal - rubberSelect.originX
                            rubberSelect.x = rubberSelect.originX
                        }
                    } else {
                        rubberSelect.x = rubberSelect.originX
                        rubberSelect.width += horizontal
                    }
                }
                if (vertical != 0) {
                    if (rubberSelect.y < rubberSelect.originY) {
                         if (vertical < 0) {
                            // Expanding up
                            rubberSelect.y += vertical
                            rubberSelect.height = rubberSelect.originY - rubberSelect.y
                        } else if (vertical < rubberSelect.height) {
                            // Expanding bottom
                            rubberSelect.y += vertical
                            rubberSelect.height = rubberSelect.originY - rubberSelect.y
                        } else {
                            // Switching direction
                            rubberSelect.height = rubberSelect.y + rubberSelect.height + horizontal - rubberSelect.originY
                            rubberSelect.y = rubberSelect.originY
                        }
                    } else {
                        rubberSelect.y = rubberSelect.originY
                        rubberSelect.height += vertical
                    }
                }
            }
        }
    }
}

