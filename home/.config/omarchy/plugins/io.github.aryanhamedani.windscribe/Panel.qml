import QtQuick
import QtQuick.Effects
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as UI

UI.Panel {
  id: root
  moduleName: "io.github.aryanhamedani.windscribe"
  ipcTarget: moduleName
  manageIpc: false
  property var snapshot: ({state: "unknown", firewall: "Unknown", location: "", ip: "", protocol: ""})
  property var preferences: ({domains: [], rangeCount: 0})
  property var locations: []
  property var presets: []
  property string page: "Overview"
  property string pollError: ""
  property string actionError: ""
  property string message: ""
  property bool confirmDisconnect: false
  property bool onlyUS: true
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("backend.py").toString().replace(/^file:\/\//, ""))
  readonly property bool busy: actionProcess.running
  readonly property bool connected: snapshot.state === "connected"
  readonly property bool transitioning: snapshot.state === "connecting" || snapshot.state === "testing"
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color muted: Qt.darker(fg, 1.4)
  readonly property string statusTitle: ({connected: "Connected", testing: "Checking tunnel", connecting: "Reconnecting", blocked: "Internet blocked", disconnected: "VPN disconnected", unknown: "Status unavailable"})[snapshot.state] || "Status unavailable"
  readonly property var filteredLocations: locations.filter(function(row) { return (!root.onlyUS || row.us) && row.label.toLowerCase().indexOf(search.text.toLowerCase()) >= 0 })
  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  function refresh() { if (!statusProcess.running) statusProcess.running = true }
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function view(name: string): void {
      if (["Overview", "Locations", "Settings", "Bypass"].indexOf(name) >= 0) { root.page = name; root.open() }
    }
    function inspect(): string { return JSON.stringify({page: root.page, opened: root.opened, state: root.snapshot.state, locations: root.locations.length, domains: (root.preferences.domains || []).length, error: root.pollError || root.actionError}) }
  }
  function loadCatalog() { if (!catalogProcess.running) catalogProcess.running = true }
  function perform(args) {
    if (busy) return
    actionError = ""; message = ""; confirmDisconnect = false
    actionProcess.command = ["/usr/bin/python3", helper].concat(args)
    actionProcess.running = true
  }
  function setOption(key, value) { perform(["set", key, value]) }
  function receive(text, kind) {
    var result
    try { result = JSON.parse(text) } catch (e) { result = {ok: false, error: "The Windscribe adapter did not respond."} }
    if (!result.ok) {
      if (kind === "status") { pollError = result.error; snapshot = {state: "unknown", firewall: "Unknown", location: "", ip: "", protocol: ""} }
      else actionError = result.error
      return
    }
    if (kind === "status") {
      snapshot = result.status; preferences = result.settings; pollError = ""
      // Shared dropdowns assign their value internally on selection. Reconcile
      // from the actual saved preferences after every poll, including failures.
      protocolChoice.value = preferences.ManualConnectionProtocol || "WireGuard"
      presetChoice.value = preferences.AmneziawgPreset || ""
    }
    else if (kind === "catalog") { locations = result.locations; presets = result.presets; actionError = "" }
    else { message = result.message || "Done"; refresh() }
  }
  onOpenedChanged: if (opened) { refresh(); loadCatalog(); confirmDisconnect = false }
  Timer { interval: root.opened ? 2000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Process {
    id: statusProcess
    command: ["/usr/bin/python3", root.helper, "status"]
    stdout: StdioCollector { onStreamFinished: root.receive(text, "status") }
  }
  Process {
    id: catalogProcess
    command: ["/usr/bin/python3", root.helper, "catalog"]
    stdout: StdioCollector { onStreamFinished: root.receive(text, "catalog") }
  }
  Process {
    id: actionProcess
    stdout: StdioCollector { onStreamFinished: root.receive(text, "action") }
  }

  UI.BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    opticalSize: Math.round(Style.bar.iconCanvas * 0.78)
    iconComponent: Component { BrandIcon { tint: barButton.active ? Commons.Color.urgent : barButton.foreground } }
    foreground: root.connected || root.transitioning ? root.barForeground : Qt.darker(root.barForeground, 1.55)
    active: root.snapshot.state === "unknown" || root.snapshot.state === "disconnected"
    tooltipText: "Windscribe · " + root.statusTitle + (root.snapshot.location ? "\n" + root.snapshot.location : "") + "\nFirewall: " + root.snapshot.firewall
    onPressed: function(button) { root.toggle() }
  }

  UI.KeyboardPanel {
    id: popup
    anchorItem: barButton; owner: root; bar: root.bar; open: root.opened
    contentWidth: fittedContentWidth(Style.space(380))
    contentHeight: fittedContentHeight(Style.space(root.page === "Overview" && !root.confirmDisconnect ? 510 : 540), Style.space(600))
    focusTarget: body
    FocusScope {
      id: body
      anchors.fill: parent
      Keys.onEscapePressed: { if (root.page !== "Overview") root.page = "Overview"; else root.close() }
      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(14)
        UI.PanelHero {
          Layout.fillWidth: true
          title: "Windscribe"
          meta: root.statusTitle
          foreground: root.fg
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          iconOpacity: root.connected ? 1 : 0.5
          iconComponent: Component {
            BrandIcon { tint: root.fg }
          }
          trailingControl: Component {
            UI.ToggleSwitch {
              checked: root.connected || root.transitioning
              busy: root.busy || root.snapshot.state === "unknown"
              foreground: root.fg
              activeFocusOnTab: true
              function activate() {
                if (busy) return
                if (root.connected || root.transitioning) { root.page = "Overview"; root.confirmDisconnect = true }
                else root.perform(["connect", "US"])
              }
              onToggled: activate()
              Keys.onSpacePressed: activate()
              Keys.onReturnPressed: activate()
            }
          }
        }
        UI.PanelSeparator { Layout.fillWidth: true; foreground: root.fg }
        RowLayout {
          Layout.fillWidth: true
          visible: root.page !== "Overview"
          UI.PanelActionButton { iconText: "󰁍"; tooltipText: "Back"; focusable: true; foreground: root.fg; onClicked: root.page = "Overview" }
          UI.PanelSectionHeader { text: root.page.toUpperCase(); foreground: root.fg; Layout.fillWidth: true }
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.actionError || root.pollError || (root.busy ? "Applying change…" : root.message)
          textFormat: Text.PlainText; wrapMode: Text.Wrap
          color: root.actionError || root.pollError ? Commons.Color.urgent : root.muted
          font.family: Style.font.family; font.pixelSize: Style.font.caption
          maximumLineCount: 3; elide: Text.ElideRight
        }
        Flickable {
          id: scroll
          Layout.fillWidth: true; Layout.fillHeight: true
          clip: true; contentWidth: width
          contentHeight: pages.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }
          Connections { target: root; function onPageChanged() { scroll.contentY = 0 } }
          Column {
            id: pages
            width: scroll.width
            spacing: Style.space(14)
            Column {
              visible: root.page === "Overview"; width: parent.width; spacing: Style.space(14)
              UI.PanelSectionHeader { text: "CONNECTION"; foreground: root.fg }
              Label { width: parent.width; text: root.snapshot.location || "No active tunnel"; font.bold: true }
              Detail { label: "VPN address"; value: root.snapshot.ip || "—" }
              Detail { label: "Protocol"; value: root.snapshot.protocol || "—" }
              Detail { label: "Windscribe firewall"; value: root.snapshot.firewall || "Unknown" }
              Detail { label: "Connected DNS"; value: root.preferences.ConnectedDNSMode === "Auto" ? "R.O.B.E.R.T." : "Custom" }
              Detail { label: "Iran bypass"; value: root.preferences.SplitTunnelingEnabled === "true" ? "Enabled · " + root.preferences.rangeCount + " ranges" : "Disabled" }
              Column {
                width: parent.width; spacing: Style.space(8); visible: root.confirmDisconnect
                Label { width: parent.width; wrapMode: Text.Wrap; text: (root.snapshot.firewall === "Always On" || root.snapshot.firewall === "On" ? "Your firewall is on. Disconnected internet access will be blocked. " : "Your firewall is off. Disconnecting can expose traffic to your ISP. ") + (root.preferences.AllowLANTraffic === "true" ? "LAN access is allowed." : "LAN access is disabled."); font.pixelSize: Style.font.caption }
                Row {
                  spacing: Style.space(8)
                  UI.Button { text: "Disconnect"; bordered: true; foreground: Commons.Color.urgent; focusable: true; onClicked: root.perform(["disconnect"]) }
                  UI.Button { text: "Cancel"; foreground: root.fg; focusable: true; onClicked: root.confirmDisconnect = false }
                }
              }
              UI.PanelSeparator { foreground: root.fg }
              NavRow { text: "Locations"; destination: "Locations"; iconText: "󰖟" }
              NavRow { text: "Connection settings"; destination: "Settings"; iconText: "󰒓" }
              NavRow { text: "Split tunneling"; destination: "Bypass"; iconText: "󰕒" }
              UI.PanelSeparator { foreground: root.fg }
              UI.Button { text: "Refresh status"; iconText: "󰑐"; foreground: root.fg; focusable: true; onClicked: root.refresh() }

            }
            Column {
              visible: root.page === "Locations"; width: parent.width; spacing: Style.space(10)
              UI.TextField { id: search; width: parent.width; placeholderText: "Search city, country or server…" }
              RowLayout { width: parent.width; Label { text: "United States only"; Layout.fillWidth: true } UI.ToggleSwitch { checked: root.onlyUS; foreground: root.fg; onToggled: root.onlyUS = !root.onlyUS; activeFocusOnTab: true; Keys.onSpacePressed: root.onlyUS = !root.onlyUS } }
              Caption { text: catalogProcess.running ? "Loading locations…" : root.filteredLocations.length + " available locations" }
              Repeater {
                model: root.filteredLocations
                UI.Button {
                  required property var modelData
                  width: pages.width; leftAlign: true; focusable: true; foreground: root.fg
                  text: modelData.city + " · " + modelData.id
                  tooltipText: modelData.label
                  selected: root.snapshot.location === modelData.city + " - " + modelData.id
                  enabled: !root.busy
                  onClicked: root.perform(["connect", modelData.id])
                }
              }
            }
            Column {
              visible: root.page === "Settings"; width: parent.width; spacing: Style.space(13)
              UI.PanelSectionHeader { text: "CONNECTION"; foreground: root.fg }
              Option { label: "Auto-connect"; description: "Reconnect to your last selected location"; keyName: "Autoconnect" }
              Option { label: "Censorship circumvention"; description: "Windscribe’s tools for restricted networks"; keyName: "CircumventCensorship" }
              UI.Dropdown {
                id: protocolChoice
                width: parent.width; label: "Protocol · port 443"; value: root.preferences.ManualConnectionProtocol || "WireGuard"
                options: ["WireGuard", "Stealth", "WStunnel", "UDP", "TCP"]; enabled: !root.busy
                onChanged: function(value) { root.setOption("ManualConnectionProtocol", value) }
              }
              UI.Dropdown {
                id: presetChoice
                width: parent.width; label: "Censorship preset"; value: root.preferences.AmneziawgPreset || ""
                options: root.presets; enabled: !root.busy && root.presets.length > 0
                onChanged: function(value) { root.perform(["preset", value]) }
              }
              UI.PanelSeparator { foreground: root.fg }
              UI.PanelSectionHeader { text: "PROTECTION"; foreground: root.fg }
              Detail { label: "Firewall policy"; value: root.preferences.FirewallMode || "Unknown" }
              Option { label: "Allow LAN traffic"; description: "Reach local devices while the firewall is on"; keyName: "AllowLANTraffic" }
              UI.Button {
                width: parent.width; text: "R.O.B.E.R.T. allowlist ↗"; bordered: true; focusable: true; foreground: root.fg
                onClicked: Qt.openUrlExternally("https://windscribe.com/myaccount#robertrules")
              }
              Label { width: parent.width; wrapMode: Text.Wrap; color: root.muted; font.pixelSize: Style.font.caption; text: "R.O.B.E.R.T. filters DNS even for bypassed sites. If a hostname resolves to 0.0.0.0, allow it in your Windscribe account." }
            }
            Column {
              visible: root.page === "Bypass"; width: parent.width; spacing: Style.space(12)
              Option { label: "Iranian traffic bypass"; description: "Excluded destinations use your Iranian connection"; keyName: "SplitTunnelingEnabled" }
              Detail { label: "Country ranges"; value: String(root.preferences.rangeCount || 0) }
              UI.Button { text: "Refresh Iranian IP ranges"; bordered: true; focusable: true; foreground: root.fg; enabled: !root.busy; onClicked: root.perform(["refresh-ranges"]) }
              Caption { text: "HOSTNAME EXCEPTIONS · " + (root.preferences.domains || []).length + "/50" }
              RowLayout {
                width: parent.width
                UI.TextField { id: domainInput; Layout.fillWidth: true; placeholderText: "app.example.ir"; onAccepted: { if (!root.busy) root.perform(["domain", "add", text]) } }
                UI.Button { text: "+ Add"; focusable: true; foreground: root.fg; enabled: !root.busy && domainInput.text.trim() !== ""; onClicked: root.perform(["domain", "add", domainInput.text]) }
              }
              Label { width: parent.width; wrapMode: Text.Wrap; color: root.muted; font.pixelSize: Style.font.caption; text: "Exact hostnames only; subdomains are separate. This changes routing, not DNS filtering." }
              Repeater {
                model: root.preferences.domains || []
                RowLayout {
                  required property string modelData
                  width: pages.width
                  Label { text: modelData; Layout.fillWidth: true; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle }
                  UI.PanelActionButton { iconText: "×"; tooltipText: "Remove bypass for " + modelData; focusable: true; foreground: root.fg; enabled: !root.busy; onClicked: root.perform(["domain", "remove", modelData]) }
                }
              }
            }
          }
        }
      }
    }
  }
  component BrandIcon: Item {
    implicitWidth: Style.font.display
    implicitHeight: Style.font.display
    property color tint: root.fg
    Image {
      id: brandImage
      anchors.fill: parent
      source: Qt.resolvedUrl(root.connected ? "assets/windscribe-connected.svg" : "assets/windscribe.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.ceil(width * 3)
      sourceSize.height: Math.ceil(height * 3)
      smooth: true
      visible: false
    }
    MultiEffect {
      anchors.fill: brandImage
      source: brandImage
      colorization: 1
      colorizationColor: parent.tint
    }
  }
  component Label: Text { textFormat: Text.PlainText; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight }
  component Caption: Label { color: root.muted; font.pixelSize: Style.font.caption }
  component Detail: RowLayout {
    property string label: ""
    property string value: ""
    width: pages.width
    Label { text: label; color: root.muted; Layout.fillWidth: true; font.pixelSize: Style.font.bodySmall }
    Label { text: value; Layout.maximumWidth: pages.width * 0.65; font.pixelSize: Style.font.bodySmall }
  }
  component NavRow: UI.Button {
    property string destination
    width: pages.width
    foreground: root.fg
    leftAlign: true
    focusable: true
    onClicked: root.page = destination
    Text { anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
  }
  component Option: Item {
    id: option
    property string keyName
    property string label
    property string description: ""
    width: pages.width
    implicitHeight: optionRow.implicitHeight + Style.space(4)
    RowLayout {
      id: optionRow
      width: parent.width
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)
        Label { text: option.label; Layout.fillWidth: true }
        Caption { text: option.description; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
      }
      UI.ToggleSwitch {
        checked: root.preferences[option.keyName] === "true"
        busy: root.busy
        foreground: root.fg
        activeFocusOnTab: true
        function activate() { if (!busy) root.setOption(option.keyName, checked ? "false" : "true") }
        onToggled: activate()
        Keys.onSpacePressed: activate()
        Keys.onReturnPressed: activate()
      }
    }
  }
}
