class_name VariantCodec
extends RefCounted

const TYPE_TAG := "__timeloop_type"


static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return {TYPE_TAG: "string_name", "value": String(value)}
		TYPE_VECTOR2I:
			return {TYPE_TAG: "vector2i", "x": value.x, "y": value.y}
		TYPE_ARRAY:
			var encoded_array: Array = []
			for item in value:
				encoded_array.append(encode(item))
			return {TYPE_TAG: "array", "items": encoded_array}
		TYPE_DICTIONARY:
			var encoded_entries: Array = []
			for key in value.keys():
				encoded_entries.append([encode(key), encode(value[key])])
			return {TYPE_TAG: "dictionary", "entries": encoded_entries}
		_:
			push_error("VariantCodec cannot encode type %s" % typeof(value))
			return null


static func decode(value: Variant) -> Variant:
	if typeof(value) != TYPE_DICTIONARY or not value.has(TYPE_TAG):
		return value

	match String(value[TYPE_TAG]):
		"string_name":
			return StringName(value.get("value", ""))
		"vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		"array":
			var decoded_array: Array = []
			for item in value.get("items", []):
				decoded_array.append(decode(item))
			return decoded_array
		"dictionary":
			var decoded_dictionary: Dictionary = {}
			for entry in value.get("entries", []):
				if entry.size() == 2:
					decoded_dictionary[decode(entry[0])] = decode(entry[1])
			return decoded_dictionary
		_:
			push_error("VariantCodec found unknown type tag: %s" % value[TYPE_TAG])
			return null


static func deep_copy(value: Variant) -> Variant:
	return decode(encode(value))
