import QtQuick

// Narrow proxy for the non-authentication first-party services used by the
// built-in bar. It intentionally has no generic property or method forwarding.
QtObject {
  required property string ownerPluginId
  required property string serviceId

  property bool enabled: false
  property var activePlayer: null
  property var sourcePlayers: []

  property var _runAction: null
  property var _playerKey: null
  property var _selectPlayer: null

  function runAction(action, showFeedback, playerId) {
    if (serviceId === "hyprvibe.media" && _runAction)
      _runAction(String(action || ""), !!showFeedback, String(playerId || ""))
  }

  function playerKey(player) {
    return serviceId === "hyprvibe.media" && _playerKey ? _playerKey(player) : ""
  }

  function selectPlayer(playerId) {
    if (serviceId === "hyprvibe.media" && _selectPlayer) _selectPlayer(String(playerId || ""))
  }
}
