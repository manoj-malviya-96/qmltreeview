import QtQuick 2.15

//REPLACED Controls 1 BY Controls 2
import QtQuick.Controls 2.15
import QtQml.Models 2.15

//ADDED: FOR TreeModelAdaptor
import com.example 1.0

ScrollView {
    id: root

    //EDIT
    property bool __activateItemOnSingleClick: false //__style ? __style.activateItemOnSingleClick : false

    default property alias __columns: root.data
    property alias __currentRow: listView.currentIndex
    property alias __currentRowItem: listView.currentItem
    property Component __itemDelegateLoader: null
    readonly property alias __listView: listView

    //__viewTypeName: "TreeView"

    property var __model: TreeModelAdaptor {
        id: modelAdaptor

        // Hack to force re-evaluation of the currentIndex binding
        property int updateCount: 0

        model: root.model

        onCollapsed: root.collapsed(index)
        onExpanded: root.expanded(index)
        onModelReset: updateCount++
        onRowsInserted: updateCount++
        onRowsRemoved: updateCount++
    }
    property Item __mouseArea: MouseArea {
        id: mouseArea

        property var clickedIndex: undefined
        readonly property alias currentIndex: root.currentIndex
        readonly property alias currentRow: root.__currentRow
        property int pressedColumn: -1
        property var pressedIndex: undefined
        property bool selectOnRelease: false

        function branchDecorationContains(x, y) {
            var clickedItem = __listView.itemAt(0, y + __listView.contentY);
            if (!(clickedItem && clickedItem.rowItem))
                return false;
            var branchDecoration = clickedItem.rowItem.branchDecoration;
            if (!branchDecoration)
                return false;
            var pos = mapToItem(branchDecoration, x, y);
            return branchDecoration.contains(Qt.point(pos.x, pos.y));
        }
        function keySelect(keyModifiers) {
            if (selectionMode) {
                if (!keyModifiers)
                    clickedIndex = currentIndex;
                if (!(keyModifiers & Qt.ControlModifier))
                    mouseSelect(currentIndex, keyModifiers, keyModifiers & Qt.ShiftModifier);
            }
        }
        function maybeWarnAboutSelectionMode() {
            if (selectionMode > enumSelectionMode.singleSelection)
                console.warn("TreeView: Non-single selection is not supported without an ItemSelectionModel.");
        }
        function mouseSelect(modelIndex, modifiers, drag) {
            if (!selection) {
                maybeWarnAboutSelectionMode();
                return;
            }
            if (selectionMode) {
                selection.setCurrentIndex(modelIndex, ItemSelectionModel.NoUpdate);
                if (selectionMode === enumSelectionMode.singleSelection) {
                    selection.select(modelIndex, ItemSelectionModel.ClearAndSelect);
                } else {
                    var selectRowRange = (drag && (selectionMode === enumSelectionMode.multiSelection || (selectionMode === enumSelectionMode.extendedSelection && modifiers & Qt.ControlModifier))) || modifiers & Qt.ShiftModifier;
                    var itemSelection = !selectRowRange || clickedIndex === modelIndex ? modelIndex : modelAdaptor.selectionForRowRange(clickedIndex, modelIndex);
                    if (selectionMode === enumSelectionMode.multiSelection || selectionMode === enumSelectionMode.extendedSelection && modifiers & Qt.ControlModifier) {
                        if (drag)
                            selection.select(itemSelection, ItemSelectionModel.ToggleCurrent);
                        else
                            selection.select(modelIndex, ItemSelectionModel.Toggle);
                    } else if (modifiers & Qt.ShiftModifier) {
                        selection.select(itemSelection, ItemSelectionModel.SelectCurrent);
                    } else {
                        clickedIndex = modelIndex; // Needed only when drag is true
                        selection.select(modelIndex, ItemSelectionModel.ClearAndSelect);
                    }
                }
            }
        }
        function selected(row) {
            if (selectionMode === enumSelectionMode.noSelection)
                return false;
            var modelIndex = null;
            if (!!selection) {
                modelIndex = modelAdaptor.mapRowToModelIndex(row);
                if (modelIndex.valid) {
                    if (selectionMode === enumSelectionMode.singleSelection)
                        return selection.currentIndex === modelIndex;
                    return selection.hasSelection && selection.isSelected(modelIndex);
                } else {
                    return false;
                }
            }
            return row === currentRow && (selectionMode === enumSelectionMode.singleSelection || (selectionMode > enumSelectionMode.singleSelection && !selection));
        }

        focus: true
        height: __listView.height
        parent: __listView
        // If there is not a touchscreen, keep the flickable from eating our mouse drags.
        // If there is a touchscreen, flicking is possible, but selection can be done only by tapping, not by dragging.
        preventStealing: false // !Settings.hasTouchScreen

        propagateComposedEvents: true
        width: __listView.width
        z: -1

        onCanceled: {
            pressedIndex = undefined;
            pressedColumn = -1;
            selectOnRelease = false;
        }
        onClicked: {
            var clickIndex = __listView.indexAt(0, mouseY + __listView.contentY);
            if (clickIndex > -1) {
                var modelIndex = modelAdaptor.mapRowToModelIndex(clickIndex);
                if (branchDecorationContains(mouse.x, mouse.y)) {
                    if (modelAdaptor.isExpanded(modelIndex))
                        modelAdaptor.collapse(modelIndex);
                    else
                        modelAdaptor.expand(modelIndex);
                } else {
                    // compensate for the fact that onPressed didn't select on press: do it here instead
                    pressedIndex = modelAdaptor.mapRowToModelIndex(clickIndex);
                    pressedColumn = __listView.columnAt(mouseX);
                    selectOnRelease = false;
                    __listView.forceActiveFocus();
                    __listView.currentIndex = clickIndex;
                    if (!clickedIndex)
                        clickedIndex = pressedIndex;
                    mouseSelect(pressedIndex, mouse.modifiers, false);
                    if (!mouse.modifiers)
                        clickedIndex = pressedIndex;
                    if (root.__activateItemOnSingleClick && !mouse.modifiers)
                        root.activated(modelIndex);
                }
                root.clicked(modelIndex);
            }
        }
        onDoubleClicked: {
            var clickIndex = __listView.indexAt(0, mouseY + __listView.contentY);
            if (clickIndex > -1) {
                var modelIndex = modelAdaptor.mapRowToModelIndex(clickIndex);
                if (!root.__activateItemOnSingleClick)
                    root.activated(modelIndex);
                root.doubleClicked(modelIndex);
            }
        }
        onExited: {
            pressedIndex = undefined;
            pressedColumn = -1;
            selectOnRelease = false;
        }
        onPositionChanged: {
            if (pressed && containsMouse) {
                var oldPressedIndex = pressedIndex;
                var pressedRow = __listView.indexAt(0, mouseY + __listView.contentY);
                pressedIndex = modelAdaptor.mapRowToModelIndex(pressedRow);
                pressedColumn = __listView.columnAt(mouseX);
                if (pressedRow > -1 && oldPressedIndex !== pressedIndex) {
                    __listView.currentIndex = pressedRow;
                    mouseSelect(pressedIndex, mouse.modifiers, true /* drag */);
                }
            }
        }
        onPressAndHold: {
            var pressIndex = __listView.indexAt(0, mouseY + __listView.contentY);
            if (pressIndex > -1) {
                var modelIndex = modelAdaptor.mapRowToModelIndex(pressIndex);
                root.pressAndHold(modelIndex);
            }
        }
        onPressed: {
            var pressedRow = __listView.indexAt(0, mouseY + __listView.contentY);
            pressedIndex = modelAdaptor.mapRowToModelIndex(pressedRow);
            pressedColumn = __listView.columnAt(mouseX);
            selectOnRelease = false;
            __listView.forceActiveFocus();
            if (pressedRow === -1 ||
            /*|| Settings.hasTouchScreen*/
            branchDecorationContains(mouse.x, mouse.y)) {
                return;
            }
            if (selectionMode === enumSelectionMode.extendedSelection && selection.isSelected(pressedIndex)) {
                selectOnRelease = true;
                return;
            }
            __listView.currentIndex = pressedRow;
            if (!clickedIndex)
                clickedIndex = pressedIndex;
            mouseSelect(pressedIndex, mouse.modifiers, false);
            if (!mouse.modifiers)
                clickedIndex = pressedIndex;
        }
        onReleased: {
            if (selectOnRelease) {
                var releasedRow = __listView.indexAt(0, mouseY + __listView.contentY);
                var releasedIndex = modelAdaptor.mapRowToModelIndex(releasedRow);
                if (releasedRow >= 0 && releasedIndex === pressedIndex)
                    mouseSelect(pressedIndex, mouse.modifiers, false);
            }
            pressedIndex = undefined;
            pressedColumn = -1;
            selectOnRelease = false;
        }
    }

    //EDIT: ADDED
    property color backgroundColor: "white"
    readonly property alias columnCount: columnModel.count
    property alias contentFooter: listView.footer
    property alias contentHeader: listView.header
    readonly property var currentIndex: modelAdaptor.updateCount, modelAdaptor.mapRowToModelIndex(__currentRow)

    //EDIT: COPIED FROM BasicTableViewStyle
    property Component headerDelegate:
    //EDIT: REPLACED BorderImage by Rectangle
    Rectangle {
        color: "gray"
        height: rowHeight // Math.round(textItem.implicitHeight * 1.2)

        Text {
            id: textItem

            anchors.fill: parent
            anchors.leftMargin: horizontalAlignment === Text.AlignLeft ? 12 : 1
            anchors.rightMargin: horizontalAlignment === Text.AlignRight ? 8 : 1
            color: textColor
            elide: Text.ElideRight

            //EDIT
            font.pixelSize: rowFontSize
            horizontalAlignment: Text.AlignLeft //styleData.textAlignment

            //EDIT
            //renderType: Settings.isMobile ? Text.QtRendering : Text.NativeRendering
            renderType: Text.NativeRendering
            text: styleData.value
            verticalAlignment: Text.AlignVCenter
        }
        Rectangle {
            color: "#ccc"
            height: parent.height - 2
            width: 1
            y: 1
        }
    }
    property bool headerVisible: true

    //EDIT: FROM BasicTableViewStyle
    property Component itemDelegate: Item {
        property int implicitWidth: label.implicitWidth + 20

        height: rowHeight //Math.max(16, label.implicitHeight)

        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            color: styleData.textColor
            elide: styleData.elideMode

            //EDIT
            font.pixelSize: rowFontSize
            horizontalAlignment: Text.AlignLeft //styleData.textAlignment

            //EDIT
            //renderType: Settings.isMobile ? Text.QtRendering : Text.NativeRendering
            renderType: Text.NativeRendering
            text: styleData.value !== undefined ? styleData.value.toString() : ""

            //EDIT
            verticalAlignment: Text.AlignVCenter
            width: parent.width - x - (horizontalAlignment === Text.AlignRight ? 8 : 1)
            x: (styleData.hasOwnProperty("depth") && styleData.column === 0) ? 0 : horizontalAlignment === Text.AlignRight ? 1 : 8
        }
    }

    //FROM BasicTableView
    property var model: null
    property alias rootIndex: modelAdaptor.rootIndex

    //EDIT: COPIED FROM BasicTableViewStyle
    property Component rowDelegate: Rectangle {
        property color selectedColor: root.activeFocus ? "lightblue" : "grey"

        color: styleData.selected ? selectedColor : backgroundColor
        height: rowHeight //Math.round(TextSingleton.implicitHeight * 1.2)

    }
    property real rowFontSize: 20
    property real rowHeight: 20
    property alias section: listView.section
    property ItemSelectionModel selection: null
    //END ADDED

    property int selectionMode: enumSelectionMode.singleSelection
    property int sortIndicatorColumn
    property int sortIndicatorOrder: Qt.AscendingOrder
    property bool sortIndicatorVisible: false
    property color textColor: "black"

    signal activated(var index)
    signal clicked(var index)
    signal collapsed(var index)
    signal doubleClicked(var index)
    signal expanded(var index)
    signal pressAndHold(var index)

    function addColumn(column) {
        return insertColumn(columnCount, column);
    }
    function collapse(index) {
        if (index.valid && index.model !== model)
            console.warn("TreeView.collapse: model and index mismatch");
        else
            modelAdaptor.collapse(index);
    }
    function expand(index) {
        if (index.valid && index.model !== model)
            console.warn("TreeView.expand: model and index mismatch");
        else
            modelAdaptor.expand(index);
    }
    function getColumn(index) {
        if (index < 0 || index >= columnCount)
            return null;
        return columnModel.get(index).columnItem;
    }
    function indexAt(x, y) {
        var obj = root.mapToItem(__listView.contentItem, x, y);
        return modelAdaptor.mapRowToModelIndex(__listView.indexAt(obj.x, obj.y));
    }
    function insertColumn(index, column) {
        //if (__isTreeView && index === 0 && columnCount > 0) {
        if (index === 0 && columnCount > 0) {
            console.warn("TreeView::insertColumn(): Can't replace column 0");
            return null;
        }
        var object = column;
        if (typeof column['createObject'] === 'function') {
            object = column.createObject(root);
        } else if (object.__view) {
            console.warn("TreeView::insertColumn(): you cannot add a column to multiple views");
            return null;
        }
        if (index >= 0 && index <= columnCount && object.accessibleRole === Accessible.ColumnHeader) {
            object.__view = root;
            columnModel.insert(index, {
                    columnItem: object
                });
            if (root.__columns[index] !== object) {
                // The new column needs to be put into __columns at the specified index
                // so the list needs to be recreated to be correct
                var arr = [];
                for (var i = 0; i < index; ++i)
                    arr.push(root.__columns[i]);
                arr.push(object);
                for (i = index; i < root.__columns.length; ++i)
                    arr.push(root.__columns[i]);
                root.__columns = arr;
            }
            return object;
        }
        if (object !== column)
            object.destroy();
        console.warn("TreeView::insertColumn(): invalid argument");
        return null;
    }
    function isExpanded(index) {
        if (index.valid && index.model !== model) {
            console.warn("TreeView.isExpanded: model and index mismatch");
            return false;
        }
        return modelAdaptor.isExpanded(index);
    }
    function moveColumn(from, to) {
        if (from < 0 || from >= columnCount || to < 0 || to >= columnCount) {
            console.warn("TreeView::moveColumn(): invalid argument");
            return;
        }
        if (__isTreeView && to === 0) {
            console.warn("TreeView::moveColumn(): Can't move column 0");
            return;
        }
        if (sortIndicatorColumn === from)
            sortIndicatorColumn = to;
        columnModel.move(from, to, 1);
    }
    function removeColumn(index) {
        if (index < 0 || index >= columnCount) {
            console.warn("TreeView::removeColumn(): invalid argument");
            return;
        }
        if (__isTreeView && index === 0) {
            console.warn("TreeView::removeColumn(): Can't remove column 0");
            return;
        }
        var column = columnModel.get(index).columnItem;
        columnModel.remove(index, 1);
        column.destroy();
    }
    function resizeColumnsToContents() {
        for (var i = 0; i < __columns.length; ++i) {
            var col = getColumn(i);
            var header = __listView.headerItem.headerRepeater.itemAt(i);
            if (col) {
                col.resizeToContents();
                if (col.width < header.implicitWidth)
                    col.width = header.implicitWidth;
            }
        }
    }

    activeFocusOnTab: true
    implicitHeight: 150
    implicitWidth: 200

    __itemDelegateLoader: Loader {
        id: itemDelegateLoader

        property TableViewColumn __column: null

        // All these properties are internal
        property int __index: index
        property Component __itemDelegate: null

        //EDIT
        readonly property int __itemIndentation: 30 * (styleData.depth + 1)
        property var __model: __rowItem ? __rowItem.itemModel : undefined
        property var __modelData: __rowItem ? __rowItem.itemModelData : undefined
        property var __mouseArea: mouseArea//null

        property Item __rowItem: null
        property TreeModelAdaptor __treeModel: null
        property bool isValid: false

        // These properties are exposed to the item delegate
        readonly property var model: __model
        readonly property var modelData: __modelData

        // Exposed to the item delegate
        property QtObject styleData: QtObject {
            readonly property int column: __index
            readonly property int depth: model && column === 0 ? model["_q_TreeView_ItemDepth"] : 0
            readonly property int elideMode: __column ? __column.elideMode : Text.ElideLeft
            readonly property bool hasActiveFocus: __rowItem ? __rowItem.activeFocus : false
            readonly property bool hasChildren: model ? model["_q_TreeView_HasChildren"] : false
            readonly property bool hasSibling: model ? model["_q_TreeView_HasSibling"] : false
            readonly property var index: model ? model["_q_TreeView_ModelIndex"] : __treeModel.index(-1, -1)
            readonly property bool isExpanded: model ? model["_q_TreeView_ItemExpanded"] : false
            readonly property bool pressed: __mouseArea && row === __mouseArea.pressedRow && column === __mouseArea.pressedColumn
            readonly property string role: __column ? __column.role : ""
            readonly property int row: __rowItem ? __rowItem.rowIndex : -1
            readonly property bool selected: __rowItem ? __rowItem.itemSelected : false
            readonly property int textAlignment: __column ? __column.horizontalAlignment : Text.AlignLeft
            readonly property color textColor: __rowItem ? __rowItem.itemTextColor : "black"
            readonly property var value: model && model.hasOwnProperty(role) ? model[role] : ""

            //FROM TableViewItemDelegateLoader styleData QtObject:
            //SIGNAL HANDLERS ARE INHERITED + CANNOT BE OVERRIDDEN BY SIMPLY REDEFINITION
            onRowChanged: if (row !== -1)
                itemDelegateLoader.isValid = true
        }

        __itemDelegate: root.itemDelegate
        __treeModel: modelAdaptor
        height: parent ? parent.height : 0
        sourceComponent: (__model === undefined || !isValid) ? null : __column && __column.delegate ? __column.delegate : __itemDelegate
        visible: __column ? __column.visible : false
        width: __column ? __column.width : 0

        onLoaded: {
            item.x = Qt.binding(function () {
                    return __itemIndentation;
                });
            item.width = Qt.binding(function () {
                    return width - __itemIndentation;
                });
        }

        Loader {
            id: branchDelegateLoader

            property QtObject styleData: itemDelegateLoader.styleData

            active: __model !== undefined && __index === 0 && styleData.hasChildren
            anchors.right: parent.item ? parent.item.left : undefined

            //EDIT
            anchors.rightMargin: 0 //__style.__indentation > width ? (__style.__indentation - width) / 2 : 0

            anchors.verticalCenter: parent.verticalCenter
            visible: itemDelegateLoader.width > __itemIndentation

            sourceComponent: Item {

                //EDIT
                height: rowHeight //16

                //EDIT
                width: 50 //indentation

                Text {
                    id: _indicator

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    color: !root.activeFocus || styleData.selected ? styleData.textColor : "#666"

                    //EDIT
                    font.pixelSize: 0.7 * rowFontSize
                    renderType: Text.NativeRendering
                    style: Text.PlainText
                    text: styleData.isExpanded ? "\u25bc" : "\u25b6"
                    visible: styleData.column === 0 && styleData.hasChildren
                }
            }

            onLoaded: if (__rowItem)
                __rowItem.branchDecoration = item
        }
    }

    // Internal stuff. Do not look
    Component.onCompleted: {
        for (var i = 0; i < __columns.length; ++i) {
            var column = __columns[i];
            if (column.accessibleRole === Accessible.ColumnHeader)
                addColumn(column);
        }
    }
    onSelectionModeChanged: if (!!selection)
        selection.clear()

    //TODO: MAKE THIS A SINGLETON: enum NOT AVAILABLE IN GLOBAL Qt. NAMESPACE
    //Enum values according to: https://doc.qt.io/qt-5/qabstracstitemview.html#enumSelectionMode-enum

    //NOTE: VALUES BELOW ARE NOT LISTED IN NUMERICAL ORDER!
    //SelectionMode { SingleSelection, ContiguousSelection, ExtendedSelection, MultiSelection, NoSelection }
    QtObject {
        id: enumSelectionMode

        property int contiguousSelection: 4
        property int extendedSelection: 3
        property int multiSelection: 2
        property int noSelection: 0
        property int singleSelection: 1
    }
    ListView {
        id: listView

        property var rowItemStack: [] // Used as a cache for rowDelegates

        function columnAt(offset) {
            var item = listView.headerItem.headerRow.childAt(offset, 0);
            return item ? item.column : -1;
        }
        function decrementCurrentIndexBlocking() {
            var oldIndex = __listView.currentIndex;
            //__scroller.blockUpdates = true;
            decrementCurrentIndex();
            //__scroller.blockUpdates = false;
            return oldIndex !== __listView.currentIndex;
        }

        /*
        //EDIT
        readonly property bool transientScrollBars: __style && !!__style.transientScrollBars
        readonly property real vScrollbarPadding: __scroller.verticalScrollBar.visible
                                                  && !transientScrollBars && Qt.platform.os === "osx" ?
                                                  __verticalScrollBar.width + __scroller.scrollBarSpacing + root.__style.padding.right : 0
       */

        /*
        readonly property bool transientScrollBars: true //__style && !!__style.transientScrollBars
        readonly property real vScrollbarPadding: __scroller.verticalScrollBar.visible
                                                  && !transientScrollBars ?
                                                  __verticalScrollBar.width + __scroller.scrollBarSpacing : 0
        */

        function incrementCurrentIndexBlocking() {
            var oldIndex = __listView.currentIndex;
            //__scroller.blockUpdates = true;
            incrementCurrentIndex();
            //__scroller.blockUpdates = false;
            return oldIndex !== __listView.currentIndex;
        }

        Keys.forwardTo: [__mouseArea]
        activeFocusOnTab: false
        anchors.fill: parent

        //ADDED
        clip: true
        contentWidth: headerItem.headerRow.width + listView.vScrollbarPadding
        // ### FIXME Late configuration of the header item requires
        // this binding to get the header visible after creation
        contentY: -headerItem.height
        currentIndex: -1
        focus: true
        headerPositioning: ListView.OverlayHeader
        highlightFollowsCurrentItem: true
        interactive: true //Settings.hasTouchScreen
        model: root.__model
        visible: columnCount > 0

        delegate: FocusScope {
            id: rowItemContainer

            property Item rowItem

            activeFocusOnTab: false
            z: rowItem.activeFocus ? 0.7 : rowItem.itemSelected ? 0.5 : 0

            Component.onCompleted: {
                // retrieve row item from cache
                if (listView.rowItemStack.length > 0)
                    rowItem = listView.rowItemStack.pop();
                else
                    rowItem = rowComponent.createObject(listView);

                // Bind container to item size
                rowItemContainer.width = Qt.binding(function () {
                        return rowItem.width;
                    });
                rowItemContainer.height = Qt.binding(function () {
                        return rowItem.height;
                    });

                // Reassign row-specific bindings
                rowItem.rowIndex = Qt.binding(function () {
                        return model.index;
                    });
                rowItem.itemModelData = Qt.binding(function () {
                        return typeof modelData === "undefined" ? null : modelData;
                    });
                rowItem.itemModel = Qt.binding(function () {
                        return model;
                    });
                rowItem.parent = rowItemContainer;
                rowItem.visible = true;
            }
            // We recycle instantiated row items to speed up list scrolling

            Component.onDestruction: {
                // move the rowItem back in cache
                if (rowItem) {
                    rowItem.visible = false;
                    rowItem.parent = null;
                    rowItem.rowIndex = -1;
                    listView.rowItemStack.push(rowItem); // return rowItem to cache
                }
            }
        }
        header: Item {
            id: tableHeader

            property alias headerRepeater: repeater
            property alias headerRow: row

            height: visible ? headerRow.height : 0
            visible: headerVisible

            //EDIT
            width: Math.max(headerRow.width + listView.vScrollbarPadding, listView.width)

            Row {
                id: row

                Repeater {
                    id: repeater

                    property int dragIndex: -1
                    property int targetIndex: -1

                    model: columnModel

                    delegate: Item {
                        id: headerRowDelegate

                        readonly property int column: index

                        //readonly property bool treeViewMovable: !__isTreeView || index > 0
                        readonly property bool treeViewMovable: index > 0

                        height: headerStyle.height

                        //EDIT
                        implicitWidth: width //columnCount === 1 ? width /*+ __verticalScrollBar.width*/ : headerStyle.implicitWidth
                        visible: modelData.visible
                        width: modelData.width
                        z: -index

                        Loader {
                            id: headerStyle

                            property QtObject styleData: QtObject {
                                readonly property int column: index
                                readonly property bool containsMouse: headerClickArea.containsMouse
                                readonly property bool pressed: headerClickArea.pressed
                                readonly property bool resizable: modelData.resizable
                                readonly property int textAlignment: modelData.horizontalAlignment
                                readonly property string value: modelData.title
                            }

                            sourceComponent: root.headerDelegate
                            width: parent.width
                        }
                        Rectangle {
                            id: targetmark

                            color: palette.highlight
                            height: parent.height
                            opacity: (treeViewMovable && index === repeater.targetIndex && repeater.targetIndex !== repeater.dragIndex) ? 0.5 : 0
                            visible: modelData.movable
                            width: parent.width

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }
                        }
                        MouseArea {
                            id: headerClickArea

                            anchors.fill: parent
                            drag.axis: Qt.YAxis
                            drag.target: treeViewMovable && modelData.movable && columnCount > 1 ? draghandle : null
                            hoverEnabled: false //Settings.hoverEnabled

                            onClicked: {
                                if (sortIndicatorColumn === index)
                                    sortIndicatorOrder = sortIndicatorOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder;
                                sortIndicatorColumn = index;
                            }
                            // Here we handle moving header sections
                            // NOTE: the direction is different from the master branch
                            // so this indicates that I am using an invalid assumption on item ordering
                            onPositionChanged: {
                                if (drag.active && modelData.movable && pressed && columnCount > 1) {
                                    // only do this while dragging
                                    for (var h = columnCount - 1; h >= 0; --h) {
                                        if (headerRow.children[h].visible && drag.target.x + headerRowDelegate.width / 2 > headerRow.children[h].x) {
                                            repeater.targetIndex = h;
                                            break;
                                        }
                                    }
                                }
                            }
                            onPressed: {
                                repeater.dragIndex = index;
                            }
                            onReleased: {
                                if (repeater.targetIndex >= 0 && repeater.targetIndex !== index) {
                                    var targetColumn = columnModel.get(repeater.targetIndex).columnItem;
                                    if (targetColumn.movable && (!__isTreeView || repeater.targetIndex > 0)) {
                                        if (sortIndicatorColumn === index)
                                            sortIndicatorColumn = repeater.targetIndex;
                                        columnModel.move(index, repeater.targetIndex, 1);
                                    }
                                }
                                repeater.targetIndex = -1;
                                repeater.dragIndex = -1;
                            }
                        }
                        Loader {
                            id: draghandle

                            property double __implicitX: headerRowDelegate.x
                            property QtObject styleData: QtObject {
                                readonly property int column: index
                                readonly property bool containsMouse: headerClickArea.containsMouse
                                readonly property bool pressed: headerClickArea.pressed
                                readonly property int textAlignment: modelData.horizontalAlignment
                                readonly property string value: modelData.title
                            }

                            height: parent.height
                            opacity: 0.5
                            parent: tableHeader
                            sourceComponent: root.headerDelegate
                            visible: headerClickArea.pressed
                            width: modelData.width
                            x: __implicitX

                            onVisibleChanged: {
                                if (!visible)
                                    x = Qt.binding(function () {
                                            return __implicitX;
                                        });
                            }
                        }
                        MouseArea {
                            id: headerResizeHandle

                            readonly property int minimumSize: 20
                            property int offset: 0

                            anchors.right: parent.right
                            anchors.rightMargin: -width / 2
                            cursorShape: enabled && repeater.dragIndex == -1 ? Qt.SplitHCursor : Qt.ArrowCursor
                            enabled: modelData.resizable && columnCount > 0
                            height: parent.height
                            preventStealing: true
                            width: 16 //Settings.hasTouchScreen ? Screen.pixelDensity * 3.5 : 16

                            onDoubleClicked: getColumn(index).resizeToContents()
                            onPositionChanged: {
                                var newHeaderWidth = modelData.width + (mouseX - offset);
                                modelData.width = Math.max(minimumSize, newHeaderWidth);
                            }
                            onPressedChanged: if (pressed)
                                offset = mouseX
                        }
                    }
                }
            }
            Loader {
                readonly property real __remainingWidth: parent.width - headerRow.width
                property QtObject styleData: QtObject {
                    readonly property int column: -1
                    readonly property bool containsMouse: false
                    readonly property bool pressed: false
                    readonly property int textAlignment: Text.AlignLeft
                    readonly property string value: ""
                }

                anchors.bottom: headerRow.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                sourceComponent: root.headerDelegate
                visible: __remainingWidth > 0
                width: __remainingWidth
                z: -1
            }
        }

        ListModel {
            id: columnModel
        }

        Component {
            id: rowComponent

            FocusScope {
                id: rowitem

                property Item branchDecoration: null
                property var itemModel
                property var itemModelData
                property bool itemSelected: __mouseArea.selected(rowIndex)

                //EDIT
                readonly property color itemTextColor: itemSelected ? "blue" : "black"
                property int rowIndex

                height: rowstyle.height
                visible: false
                width: itemrow.width

                onActiveFocusChanged: {
                    if (activeFocus)
                        listView.currentIndex = rowIndex;
                }

                Loader {
                    id: rowstyle

                    readonly property var model: rowitem.itemModel
                    readonly property var modelData: rowitem.itemModelData

                    // these properties are exposed to the row delegate
                    // Note: these properties should be mirrored in the row filler as well
                    property QtObject styleData: QtObject {
                        readonly property bool hasActiveFocus: rowitem.activeFocus
                        readonly property bool pressed: rowitem.rowIndex === __mouseArea.pressedRow
                        readonly property int row: rowitem.rowIndex
                        readonly property bool selected: rowitem.itemSelected
                    }

                    // Row fills the view width regardless of item size
                    // But scrollbar should not adjust to it
                    height: item ? item.height : 16
                    // row delegate
                    sourceComponent: rowitem.itemModel !== undefined ? root.rowDelegate : null

                    //EDIT
                    width: parent.width // + __horizontalScrollBar.width
                    x: listView.contentX
                }
                Row {
                    id: itemrow

                    height: parent.height

                    Repeater {
                        delegate: __itemDelegateLoader
                        model: columnModel

                        onItemAdded: {
                            var columnItem = columnModel.get(index).columnItem;
                            item.__rowItem = rowitem;
                            item.__column = columnItem;
                        }
                    }
                }
            }
        }
    }
}
