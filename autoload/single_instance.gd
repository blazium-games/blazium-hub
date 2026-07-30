extends Node
## Single-instance lock via localhost TCP. Second process forwards URI then exits.

const PORT := 39217
const HOST := "127.0.0.1"

var _server: TCPServer
var _clients: Array[StreamPeerTCP] = []


func _skip_for_autowork() -> bool:
	if OS.get_environment("HUB_AUTOWORK") == "1":
		return true
	for a in OS.get_cmdline_args():
		if str(a).ends_with("run_tests.gd"):
			return true
	return false


func _ready() -> void:
	if _skip_for_autowork():
		return
	_server = TCPServer.new()
	var err := _server.listen(PORT, HOST)
	if err != OK:
		# Another Hub is listening — forward argv URI and quit.
		_forward_and_quit()
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _server and _server.is_connection_available():
		var peer := _server.take_connection()
		if peer:
			_clients.append(peer)
	var still: Array[StreamPeerTCP] = []
	for peer in _clients:
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			if peer.get_available_bytes() > 0:
				var msg := peer.get_utf8_string(peer.get_available_bytes()).strip_edges()
				if msg.begins_with("URI "):
					var uri := msg.substr(4).strip_edges()
					if UriRouter:
						UriRouter.handle_uri(uri)
						UriRouter.show_hub()
				elif msg == "SHOW":
					if UriRouter:
						UriRouter.show_hub()
			still.append(peer)
		elif status == StreamPeerTCP.STATUS_CONNECTING:
			still.append(peer)
	_clients = still


func _forward_and_quit() -> void:
	var uri := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("blazium:"):
			uri = str(a)
			break
	if uri.is_empty():
		for a in OS.get_cmdline_args():
			if str(a).begins_with("blazium:"):
				uri = str(a)
				break
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host(HOST, PORT) != OK:
		get_tree().quit()
		return
	var deadline := Time.get_ticks_msec() + 2000
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < deadline:
		peer.poll()
		OS.delay_msec(10)
	peer.poll()
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if uri.is_empty():
			peer.put_data("SHOW\n".to_utf8_buffer())
		else:
			peer.put_data(("URI %s\n" % uri).to_utf8_buffer())
		OS.delay_msec(50)
	get_tree().quit()
