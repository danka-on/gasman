extends Node

enum LogLevel {DEBUG, INFO, WARNING, ERROR, NONE}
var current_level = LogLevel.WARNING # Default log level

func _ready():
    # Set higher log level in debug builds
    if OS.is_debug_build():
        current_level = LogLevel.DEBUG
    
    print("Logger initialized with level: ", get_level_name(current_level))

func debug(message):
    if current_level <= LogLevel.DEBUG:
        print("[DEBUG] " + str(message))

func info(message):
    if current_level <= LogLevel.INFO:
        print("[INFO] " + str(message))

func warning(message):
    if current_level <= LogLevel.WARNING:
        push_warning("[WARNING] " + str(message))

func error(message):
    if current_level <= LogLevel.ERROR:
        push_error("[ERROR] " + str(message))

func set_level(level: LogLevel):
    current_level = level
    print("Logger level set to: ", get_level_name(level))

func get_level_name(level: LogLevel) -> String:
    match level:
        LogLevel.DEBUG: return "DEBUG"
        LogLevel.INFO: return "INFO"
        LogLevel.WARNING: return "WARNING"
        LogLevel.ERROR: return "ERROR"
        LogLevel.NONE: return "NONE"
        _: return "UNKNOWN"
