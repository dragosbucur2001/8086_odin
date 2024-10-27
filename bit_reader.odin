package emulator

BitReader :: struct {
	data:    []byte,
	it:      u64,
	bit_pos: i8,
}

FIRST_BIT :: 7

init_bit_reader :: proc(data: []byte) -> BitReader {
	assert(data != nil)

	return BitReader{data = data, it = 0, bit_pos = FIRST_BIT}
}

read_bits :: proc(using reader: ^BitReader, bit_count: u8) -> u8 {
	assert(bit_count <= 8)
	assert(!finished(reader))

	result: u8 = 0

	for i in 0 ..< bit_count {
		if (bit_pos < 0) {
			bit_pos = FIRST_BIT
			it += 1
			assert(!finished(reader))
		}

		casted := cast(u8)bit_pos
		result <<= 1
		result |= (data[it] & (1 << casted)) >> casted

		bit_pos -= 1
	}

	return result
}

get_byte :: proc(using reader: ^BitReader) -> u8 {
	return data[it]
}

finished :: proc(using reader: ^BitReader) -> b8 {
	return it >= cast(u64)len(data)
}
