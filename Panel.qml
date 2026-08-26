import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
Panel { id:root; moduleName:"io.github.jeremylongshore.desk-transition"; ipcTarget:"io.github.jeremylongshore.desk-transition"; manageIpc:false
 property var anchorItem:null; property var hostWidget:null; property bool openedFromHotkey:false; readonly property var barIdentity:hostWidget||root; readonly property string helperPath:Qt.resolvedUrl("bin/desk-transition").toString().replace(/^file:\/\//,""); property var state:({valid:false,monitors:[]}); property bool loaded:false
 readonly property bool isAlert:false; readonly property string label:loaded?Model.pillText(state):"DESK"; readonly property string tooltip:loaded?Model.tooltipText(state):"Reading local display state…"
 function open(){openedFromHotkey=false;root.controller.show();root.refresh()} function openFromHotkey(){openedFromHotkey=true;root.controller.show();root.refresh()} function close(){root.controller.hide()} function toggle(){if(root.opened)root.close();else root.openFromHotkey()} function switchPanel(d){return root.bar&&typeof root.bar.switchPanelFrom==="function"?root.bar.switchPanelFrom(root.barIdentity,d):false} function refresh(){if(!scan.running)scan.running=true} function run(a){if(!act.running){act.command=[root.helperPath].concat(a);act.running=true}}
 Process{id:scan;command:[root.helperPath,"--scan"];stdout:StdioCollector{waitForEnd:true;onStreamFinished:{var x=Model.parse(text);if(x.valid){root.state=x;root.loaded=true}}}} Process{id:act;command:[];onExited:root.refresh()} Timer{interval:15000;running:true;repeat:true;triggeredOnStart:true;onTriggered:root.refresh()}
 IpcHandler{target:root.ipcTarget;function open():void{root.openFromHotkey()}function close():void{root.close()}function show():void{root.openFromHotkey()}function hide():void{root.close()}function toggle():void{root.toggle()}function refresh():void{if(root.hostWidget&&typeof root.hostWidget.broadcast==="function")root.hostWidget.broadcast("refresh");else root.refresh()}}
 KeyboardPanel{id:panel;anchorItem:root.anchorItem;owner:root.barIdentity;bar:root.bar;open:root.opened;centerOnBar:true;focusTarget:keys;contentWidth:panel.fittedContentWidth(Style.space(430));contentHeight:panel.fittedContentHeight(content.implicitHeight)
  PanelKeyCatcher{id:keys;anchors.fill:parent;onCloseRequested:root.close();onTabRequested:function(d){root.switchPanel(d)} Column{id:content;anchors.fill:parent;spacing:Style.space(9)
   PanelHero{title:root.state.monitors.length?root.state.monitors.length+" ACTIVE DISPLAYS":"NO ACTIVE DISPLAY";meta:"Desk arranges only currently active outputs. Laptop only shifts focus to an internal display.";foreground:root.bar?root.bar.foreground:Color.foreground;fontFamily:root.bar?root.bar.fontFamily:Style.font.family} PanelSeparator{foreground:root.bar?root.bar.foreground:Color.foreground}
   Row{
    x:Style.space(16);width:parent.width-Style.space(32);spacing:Style.space(22)
    Text{text:"DESK";textFormat:Text.PlainText;width:Style.space(70);elide:Text.ElideRight;color:root.bar?root.bar.foreground:Color.foreground;font.family:root.bar?root.bar.fontFamily:Style.font.family;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.run(["--desk"])}}
    Text{text:"LAPTOP";textFormat:Text.PlainText;width:Style.space(85);elide:Text.ElideRight;color:root.bar?root.bar.foreground:Color.foreground;font.family:root.bar?root.bar.fontFamily:Style.font.family;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.run(["--laptop"])}}
   }
   Repeater{model:root.state.monitors
    Item{required property var modelData;width:content.width;height:Style.space(28)
     Text{anchors.left:parent.left;anchors.leftMargin:Style.space(16);anchors.verticalCenter:parent.verticalCenter;text:modelData.name+"  "+modelData.width+"×"+modelData.height;textFormat:Text.PlainText;width:parent.width-Style.space(32);elide:Text.ElideRight;color:modelData.focused?(root.bar?root.bar.foreground:Color.foreground):(root.bar?Qt.darker(root.bar.foreground,1.3):Color.muted);font.family:root.bar?root.bar.fontFamily:Style.font.family;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.run(["--focus",modelData.name])}}
    }
   }
  }}
 }
}
