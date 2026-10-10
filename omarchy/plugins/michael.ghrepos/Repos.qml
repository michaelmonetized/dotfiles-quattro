import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "michael.ghrepos"
    ipcTarget: "ghrepos"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    property var repos: []
    property var shown: []
    property string error: ""
    property double updatedAt: 0
    property string sortKey: "commitDate"
    property bool descending: true
    property bool attention: false
    readonly property string helper: Qt.resolvedUrl("backend.py").toString().replace(/^file:\/\//, "")
    function colorFor(tone) { return tone === "success" ? "#a6e3a1" : tone === "running" ? "#f9e2af" : tone === "failed" ? "#f38ba8" : Color.muted }
    function deployment(r) {
        var ds=r.deployments || []
        if (!ds.length) return {state:"—",tone:"neutral",url:"",name:"No linked Vercel project"}
        return ds.slice().sort((a,b) => ({failed:0,running:1,neutral:2,success:3}[a.tone])-({failed:0,running:1,neutral:2,success:3}[b.tone]))[0]
    }
    function filter() {
        var q=search.text.toLowerCase().trim()
        shown=repos.filter(r => (r.name+" "+(r.ownerName || r.owner.login)).toLowerCase().indexOf(q)>=0 && (!attention || r.pullRequests>0 || r.issues>0 || (r.actions || {}).tone === "failed" || deployment(r).tone === "failed")).sort(function(a,b) {
            var av=sortKey === "deploy" ? deployment(a).state : sortKey === "actions" ? (a.actions || {}).state : a[sortKey]
            var bv=sortKey === "deploy" ? deployment(b).state : sortKey === "actions" ? (b.actions || {}).state : b[sortKey]
            av=av === undefined || av === null ? "" : av; bv=bv === undefined || bv === null ? "" : bv
            var n=av < bv ? -1 : av > bv ? 1 : a.name.localeCompare(b.name)
            return descending ? -n : n
        })
    }
    function sort(key) { descending=sortKey===key ? !descending : key!=='name' && key!=='ownerName'; sortKey=key; filter() }
    function accept(text) {
        try { var d=JSON.parse(text); repos=d.repos; updatedAt=d.updatedAt || 0; error=d.error || ""; filter() }
        catch(e) { error="Could not read repository data" }
    }
    function refresh(force) { if (!worker.running) { worker.command=[helper].concat(force ? ["--force"] : []); worker.running=true } }
    onOpenedChanged: if(opened) { refresh(false); Qt.callLater(() => search.forceActiveFocus()) }
    Component.onCompleted: cache.running=true
    Process { id: cache; command:[root.helper,"--cached"]; stdout: StdioCollector { onStreamFinished: root.accept(text) } }
    Process {
        id: worker
        stdout: SplitParser { onRead: data => root.accept(data) }
        onExited: (code,status) => { if(code!==0) root.error="Repository refresh exited with code "+code }
    }
    Timer { interval:300000; repeat:true; running:root.opened; onTriggered:root.refresh(false) }
    IpcHandler {
        target: "ghrepos-data"
        function status(): string { return JSON.stringify({count:root.repos.length,shown:root.shown.length,opened:root.opened,query:search.text,sort:root.sortKey,descending:root.descending,refreshing:worker.running,error:root.error,updatedAt:root.updatedAt}) }
        function search(text:string): void { search.text=text }
        function refresh(): void { root.refresh(true) }
        function sort(key:string): void { root.sort(key) }
    }
    BarIconButton { id:button; anchors.fill:parent; bar:root.bar; text:""; tooltipText:"Repositories · GitHub / Vercel / Actions"; onPressed:root.toggle() }
    KeyboardPanel {
        id:popup; anchorItem:button; owner:root; bar:root.bar; open:root.opened
        focusTarget: search
        contentWidth: Math.min(1120, (screen ? screen.width : 1200) - 40)
        contentHeight: Math.min(640, (screen ? screen.height : 800) - 100)
        ColumnLayout {
            anchors.fill:parent; spacing:10
            RowLayout {
                Layout.fillWidth:true
                Text { text:"Repositories"; color:Color.popups.text; font.family:Style.font.family; font.pixelSize:22; font.bold:true }
                Text { text:root.shown.length+" / "+root.repos.length; color:Color.muted; font.pixelSize:13 }
                Item { Layout.fillWidth:true }
                Controls.Button { text:root.attention ? "● Attention" : "Attention"; checkable:true; checked:root.attention; onClicked: { root.attention=checked; root.filter() } }
                Controls.Button { text:worker.running ? "Refreshing…" : "Refresh"; enabled:!worker.running; onClicked:root.refresh(true) }
                Controls.Button { text:"✕"; onClicked:root.close() }
            }
            Controls.TextField {
                id:search; Layout.fillWidth:true; placeholderText:"Search repositories or owners…"; selectByMouse:true
                color:Color.popups.text; placeholderTextColor:Color.muted
                background:Rectangle { color:Qt.rgba(0.5,0.6,0.8,0.08); radius:6; border.color:search.activeFocus ? "#89b4fa" : Color.muted }
                onTextChanged:root.filter()
                Keys.onEscapePressed:root.close()
                Keys.onDownPressed: { list.forceActiveFocus(); list.currentIndex=0 }
                Keys.onReturnPressed:if(root.shown.length) Qt.openUrlExternally(root.shown[0].url)
            }
            Controls.ScrollView {
                Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                contentWidth:Math.max(1040,width)
                Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AsNeeded
                Item {
                    width:Math.max(1040,parent.width); height:parent.height
                    ColumnLayout {
                        anchors.fill:parent; spacing:0
                        Row {
                            Layout.fillWidth:true
                            Repeater {
                                model:[{t:"Repository",k:"name",w:310},{t:"Owner",k:"ownerName",w:80},{t:"Last commit",k:"commitDate",w:200},{t:"PRs",k:"pullRequests",w:75},{t:"Comments",k:"comments",w:110},{t:"Issues",k:"issues",w:75},{t:"▲",k:"deploy",w:90},{t:"󰢛",k:"actions",w:100}]
                                Cell { required property var modelData; width:modelData.w; height:44; sortable:true; centered:modelData.k==="ownerName" || modelData.k==="deploy" || modelData.k==="actions"; text:modelData.t+(root.sortKey===modelData.k ? (root.descending ? " ↓" : " ↑") : ""); bold:true; ink:Color.muted; tooltip:"Sort by "+modelData.t; onActivated:root.sort(modelData.k) }
                            }
                        }
                        Rectangle { Layout.fillWidth:true; height:1; color:Color.muted; opacity:0.3 }
                        ListView {
                            id:list; Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                            model:root.shown; boundsBehavior:Flickable.StopAtBounds; reuseItems:true
                            Controls.ScrollBar.vertical:Controls.ScrollBar {}
                            Keys.onEscapePressed:root.close()
                            Keys.onReturnPressed:if(currentIndex>=0) Qt.openUrlExternally(root.shown[currentIndex].url)
                            delegate:Rectangle {
                                required property var modelData
                                required property int index
                                width:list.width; height:58
                                color:list.activeFocus && list.currentIndex===index ? "#3089b4fa" : index%2 ? Qt.rgba(0.5,0.6,0.8,0.04) : "transparent"
                                Row {
                                    Cell { width:310; text:modelData.name; bold:true; url:modelData.url; tooltip:modelData.url+((modelData.errors || []).length ? "\n"+modelData.errors.join("\n") : "") }
                                    Cell {
                                        width:80; url:"https://github.com/"+(modelData.ownerName || modelData.owner.login)
                                        tooltip:modelData.ownerName || modelData.owner.login
                                        Image { anchors.centerIn:parent; width:28; height:28; source:modelData.avatar || ""; asynchronous:true; sourceSize.width:56; sourceSize.height:56 }
                                    }
                                    Cell { width:200; text:modelData.commitDate ? Qt.formatDateTime(new Date(modelData.commitDate),"MMM d, yyyy HH:mm") : "—"; url:modelData.commitUrl || ""; tooltip:modelData.commitDate || "Commit unavailable / empty repository" }
                                    Cell { width:75; text:String(modelData.pullRequests); url:modelData.url+"/pulls"; tooltip:"Open pull requests" }
                                    Cell { width:110; text:modelData.comments===null || modelData.comments===undefined ? "—" : String(modelData.comments); url:modelData.url+"/pulls"; tooltip:"Conversation + inline review comments across all open PRs" }
                                    Cell { width:75; text:String(modelData.issues); url:modelData.url+"/issues"; tooltip:"Open issues" }
                                    Cell { width:90; centered:true; textSize:19; text:"▲"; ink:root.colorFor(root.deployment(modelData).tone); url:root.deployment(modelData).tone === "success" ? (root.deployment(modelData).site || "") : (root.deployment(modelData).buildLogUrl || ""); tooltip:(modelData.deployments || []).map(d=>d.name+": "+d.state).join("\n") || "No linked Vercel project" }
                                    Cell { width:100; centered:true; textSize:22; text:"󰢛"; ink:root.colorFor((modelData.actions || {}).tone); url:(modelData.actions || {}).tone === "success" ? "" : (modelData.actions || {}).tone === "failed" ? (((modelData.actions || {}).url || "").indexOf("https://app.blacksmith.sh/") === 0 ? modelData.actions.url : "") : ((modelData.actions || {}).url || ""); tooltip:((modelData.actions || {}).name || "Latest GitHub Actions run")+"\n"+((modelData.actions || {}).state || "loading")+((modelData.actions || {}).logNote ? "\n"+modelData.actions.logNote : "") }
                                }
                            }
                            Text { anchors.centerIn:parent; visible:list.count===0; text:worker.running ? "Loading your repositories…" : search.text ? "No matching repositories" : "Refresh to load repositories"; color:Color.muted }
                        }
                    }
                }
            }
            Text { Layout.fillWidth:true; elide:Text.ElideRight; color:root.error ? "#f38ba8" : Color.muted; font.pixelSize:12; text:root.error || (worker.running ? "Refreshing in the background…" : root.updatedAt ? "Updated "+Qt.formatDateTime(new Date(root.updatedAt*1000),"HH:mm") : "No cached data")+"  ·  Green success  /  Yellow running  /  Red failed  /  Gray unknown or inactive" }
        }
    }
}
