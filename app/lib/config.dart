/// Address of the realtime game server. Fixed at build time; override with
/// `--dart-define=SERVER_URL=ws://localhost:8080` to test against a local
/// server.
const String kServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'wss://puzzer.deadgroup.dev');
