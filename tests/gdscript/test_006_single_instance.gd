extends AutoworkTest


func test_006_single_instance_skip_during_autowork() -> void:
	assert_true(SingleInstance != null, "SingleInstance autoload")
	assert_true(SingleInstance._skip_for_autowork(), "Autowork skips TCP lock")
	assert_true(SingleInstance._server == null, "no TCP server while Autowork runs")


func test_006_protocol_constants() -> void:
	assert_eq(SingleInstance.PORT, 39217)
	assert_eq(SingleInstance.HOST, "127.0.0.1")


func test_006_close_request_keeps_lock() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/single_instance.gd")
	assert_false(src.contains("NOTIFICATION_WM_CLOSE_REQUEST"), "window close must not drop the single-instance port")
	assert_true(src.contains("NOTIFICATION_PREDELETE"), "process exit still releases the port")
