## LoggieMsg represents a mutable object that holds a string message ([member content]), its original unmutated form ([member originalContent]), and
## a bunch of helper methods that make it easy to manipulate the content and chain together additions and changes to it.
## [br][br]For example:
## [codeblock]
### Prints: "Hello world!" at the INFO debug level.
##var msg = LoggieMsg.new("Hello world").color(Color.RED).suffix("!").info() 
##[/codeblock]
## [br] You can also use [method Loggie.msg] to quickly construct a message.
## [br] Example of usage:
## [codeblock]Loggie.msg("Hello world").color(Color("#ffffff")).suffix("!").info()[/codeblock]
class_name LoggieMsg extends RefCounted

## The original string content of this message, as it existed at the moment this message was instantiated.
## This content can be accessed with [method getOriginal], or you can convert the current [member content] to its original form
## by calling [method toOriginal].
var originalContent : String = ""

## The string content of this message. By calling various helper methods in this class, this content is further altered.
## You can then output it with methods like [method info], [method debug], etc.
var content : String = ""

## The (key string) domain this message belongs to.
## "" is the default domain which is always enabled.
## If this message attempts to be outputted, but belongs to a disabled domain, it will not be outputted.
## You can change which domains are enabled in Loggie at any time with [Loggie.set_domain_enabled].
## This is useful for creating blocks of debugging output that you can simply turn off/on with a boolean when you actually need them.
var domain_name : String = ""

## Whether this message should be preprocessed and modified during [method output].
var preprocess : bool = true

func _init(msg = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	self.content = LoggieTools.concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5)
	self.originalContent = self.content

## Outputs the given string [param msg] at the given output level to the standard output using either [method print_rich] or [method print].
## It also does a number of changes to the given [param msg] based on various Loggie settings.
## Designed to be called internally. You should consider using [method info], [method error], [method warn], [method notice], [method debug] instead.
func output(level : LoggieTools.LogLevel, msg : String, domain : String = "") -> void:
	# We don't output the message if the settings dictate that messages of that level shouldn't be outputted.
	if level > Loggie.settings.log_level:
		return

	# We don't output the message if the domain from which it comes is not enabled.
	if not Loggie.is_domain_enabled(domain):
		return

	if self.preprocess:
		# We append the name of the domain if that setting is enabled.
		if !domain.is_empty() and Loggie.settings.output_message_domain == true:
			msg = Loggie.settings.format_domain_prefix % [domain, msg]

		# We prepend the name of the class that called the function which resulted in this output being generated
		# (if Loggie settings are configured to do so).
		if Loggie.settings.derive_and_show_class_names == true:
			var stackFrame : Dictionary = LoggieTools.get_current_stack_frame_data()
			var className : String

			var scriptPath = stackFrame.source
			if Loggie.classNames.has(scriptPath):
				className = Loggie.classNames[scriptPath]
			else:
				className = LoggieTools.extract_class_name_from_gd_script(scriptPath)
			
			msg = "[b]({className})[/b] {msg}".format({
				"className" : className,
				"msg" : msg
			})

		# We prepend a timestamp to the message (if Loggie settings are configured to do so).
		if Loggie.settings.show_timestamps == true:
			msg = "{timestamp} {msg}".format({
				"timestamp" : Time.get_datetime_string_from_system(Loggie.settings.timestamps_use_utc, true),
				"msg" : msg
			})

	var usedTerminalMode = LoggieTools.TerminalMode.PLAIN if Loggie.is_in_production() else Loggie.settings.terminal_mode
	match usedTerminalMode:
		LoggieTools.TerminalMode.ANSI:
			# We put the message through the rich_to_ANSI converted which takes care of converting BBCode
			# to appropriate ANSI. (Only if the TerminalMode is set to ANSI).
			# Godot claims to be already preparing BBCode output for ANSI, but it only works with a small
			# predefined set of colors, and I think it totally strips stuff like [b], [i], etc.
			# It is possible to display those stylings in ANSI, but we have to do our own conversion here
			# to support these features instead of having them stripped.
			msg = LoggieTools.rich_to_ANSI(msg)
			print_rich(msg)
		LoggieTools.TerminalMode.BBCODE:
			print_rich(msg)
		LoggieTools.TerminalMode.PLAIN, _:
			var plainMsg = LoggieTools.remove_BBCode(msg)
			print(plainMsg)

## Outputs this message from Loggie as an Error type message.
## The [Loggie.settings.log_level] must be equal to or higher to the ERROR level for this to work.
func error() -> LoggieMsg:
	var msg = Loggie.settings.format_error_msg % [self.content]
	output(LoggieTools.LogLevel.ERROR, msg, self.domain_name)
	if Loggie.settings.print_errors_to_console and Loggie.settings.log_level >= LoggieTools.LogLevel.ERROR:
		push_error(self.string())
	return self

## Outputs this message from Loggie as an Warning type message.
## The [Loggie.settings.log_level] must be equal to or higher to the WARN level for this to work.
func warn() -> LoggieMsg:
	var msg = Loggie.settings.format_warning_msg % [self.content]
	output(LoggieTools.LogLevel.WARN, msg, self.domain_name)
	if Loggie.settings.print_warnings_to_console and Loggie.settings.log_level >= LoggieTools.LogLevel.WARN:
		push_warning(self.string())
	return self

## Outputs this message from Loggie as an Notice type message.
## The [Loggie.settings.log_level] must be equal to or higher to the NOTICE level for this to work.
func notice() -> LoggieMsg:
	var msg = Loggie.settings.format_notice_msg % [self.content]
	output(LoggieTools.LogLevel.NOTICE, msg, self.domain_name)
	return self

## Outputs this message from Loggie as an Info type message.
## The [Loggie.settings.log_level] must be equal to or higher to the INFO level for this to work.
func info() -> LoggieMsg:
	var msg = Loggie.settings.format_info_msg % [self.content]
	output(LoggieTools.LogLevel.INFO, msg, self.domain_name)
	return self

## Outputs this message from Loggie as a Debug type message.
## The [Loggie.settings.log_level] must be equal to or higher to the DEBUG level for this to work.
func debug() -> LoggieMsg:
	var msg = Loggie.settings.format_debug_msg % [self.content]
	output(LoggieTools.LogLevel.DEBUG, msg, self.domain_name)
	if Loggie.settings.use_print_debug_for_debug_msg and Loggie.settings.log_level >= LoggieTools.LogLevel.DEBUG:
		print_debug(self.string())
	return self

## Returns the string content of this message.
func string() -> String:
	return self.content

## Converts the current content of this message to an ANSI compatible form.
func toANSI() -> LoggieMsg:
	self.content = LoggieTools.rich_to_ANSI(self.content)
	return self

## Strips all the BBCode in the current content of this message.
func stripBBCode() -> LoggieMsg:
	self.content = LoggieTools.remove_BBCode(self.content)
	return self

## Returns the original version of this message (as it was in the moment when it was constructed).
func getOriginal() -> String:
	return self.originalContent

## Changes the content of this message to be equal to the original version of this message (as it was in the moment when it was constructed).
func toOriginal() -> LoggieMsg:
	self.content = self.originalContent
	return self

## Wraps the current content of this message in the given color.
## The [param color] can be provided as a [Color], a recognized Godot color name (String, e.g. "red"), or a color hex code (String, e.g. "#ff0000").
func color(_color : Variant) -> LoggieMsg:
	if _color is Color:
		_color = _color.to_html()
	
	self.content = "[color=%s]%s[/color]" % [_color, self.content]
	return self

## Stylizes the current content of this message as a header.
func header() -> LoggieMsg:
	self.content = Loggie.settings.format_header % self.content
	return self

## Constructs a decorative box with the given horizontal padding around the current content
## of this message. Messages containing a box are not going to be preprocessed, so they are best
## used only as a special header or decoration.
func box(h_padding : int = 4):
	var stripped_content = LoggieTools.remove_BBCode(self.content).strip_edges(true, true)
	var content_length = stripped_content.length()
	var h_fill_length = content_length + (h_padding * 2)
	var box_character_source = Loggie.settings.box_symbols_compatible if Loggie.settings.box_characters_mode == LoggieTools.BoxCharactersMode.COMPATIBLE else Loggie.settings.box_symbols_pretty

	var top_row_design = "{top_left_corner}{h_fill}{top_right_corner}".format({
		"top_left_corner" : box_character_source.top_left,
		"h_fill" : box_character_source.h_line.repeat(h_fill_length),
		"top_right_corner" : box_character_source.top_right
	})

	var middle_row_design = "{vert_line}{padding}{content}{space_fill}{padding}{vert_line}".format({
		"vert_line" : box_character_source.v_line,
		"content" : self.content,
		"padding" : " ".repeat(h_padding),
		"space_fill" : " ".repeat(h_fill_length - stripped_content.length() - h_padding*2)
	})
	
	var bottom_row_design = "{bottom_left_corner}{h_fill}{bottom_right_corner}".format({
		"bottom_left_corner" : box_character_source.bottom_left,
		"h_fill" : box_character_source.h_line.repeat(h_fill_length),
		"bottom_right_corner" : box_character_source.bottom_right
	})
	
	self.content = "{top_row}\n{middle_row}\n{bottom_row}\n".format({
		"top_row" : top_row_design,
		"middle_row" : middle_row_design,
		"bottom_row" : bottom_row_design
	})
	
	self.preprocessed(false)

	return self

## Concatenates the content of another [LoggieMsg] to the end of this message (optionally with a separator string between them).
func add(logmsg : LoggieMsg, separator : String = "") -> LoggieMsg:
	self.content = "{msg}{separator}{newContent}".format({
		"msg" : self.content,
		"separator" : separator,
		"newContent" : logmsg.content
	})
	return self
	
## Appends a new message to the end of this message.
func append(msg : String, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
	self.content = self.content + LoggieTools.concatenate_msg_and_args(msg, arg1, arg2, arg3, arg4, arg5)
	return self

## Adds a newline to the nl()end of this message.
func nl(amount : int = 1) -> LoggieMsg:
	self.content += "\n".repeat(amount)
	return self

## Adds a space to the end of this message.
func space(amount : int = 1) -> LoggieMsg:
	self.content += " ".repeat(amount)
	return self

## Sets this message to belong to the domain with the given name.
## If it attempts to be outputted, but the domain is disabled, it won't be outputted.
func domain(_domain_name : String) -> LoggieMsg:
	self.domain_name = _domain_name
	return self

## Prepends the given prefix string to the start of the message with the provided separator.
func prefix(prefix : String, separator : String = "") -> LoggieMsg:
	self.content = "{prefix}{space}{content}".format({
		"prefix" : prefix,
		"separator" : separator,
		"content" : self.content
	})
	return self

## Appends the given suffix string to the end of the message with the provided separator.
func suffix(suffix : String, separator : String = "") -> LoggieMsg:
	self.content = "{content}{separator}{suffix}".format({
		"suffix" : suffix,
		"separator" : separator,
		"content" : self.content
	})
	return self

## Appends a horizontal separator with the given length to the message.
## If [param alternative_symbol] is provided, it should be a String, and it will be used as the symbol for the separator instead of the default one.
func hseparator(size : int = 16, alternative_symbol : Variant = null) -> LoggieMsg:
	var symbol = Loggie.settings.h_separator_symbol if alternative_symbol == null else str(alternative_symbol)
	self.content += (symbol.repeat(size))
	return self

## Sets whether this message should be preprocessed and potentially modified with prefixes and suffixes during [method output].
## If turned off, while outputting this message, Loggie will skip the steps where it appends the messaage domain, class name, timestamp, etc.
## Whether preprocess is set to true doesn't affect the final conversion from RICH to ANSI or PLAIN, which always happens 
## under some circumstances that based on other settings.
func preprocessed(shouldPreprocess : bool) -> LoggieMsg:
	self.preprocess = shouldPreprocess
	return self