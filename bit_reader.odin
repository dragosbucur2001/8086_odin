package emulator

BitReader :: struct {
	data:      []byte,
	stable_it: u64,
	it:        u64,
	bit_pos:   i8,
}

FIRST_BIT :: 7
END_BIT :: -1

init_bit_reader :: proc(data: []byte) -> BitReader {
	assert(data != nil)

	return BitReader{data = data, stable_it = 0, it = 0, bit_pos = FIRST_BIT}
}

get_byte :: proc(using reader: ^BitReader) -> u8 {
	return data[it]
}

read_bits :: proc(using reader: ^BitReader, bit_count: u8) -> (result: u8) {
	assert(bit_count <= 8)
	assert(!finished(reader))

	for i in 0 ..< bit_count {
		if (bit_pos < 0) {
			assert(bit_pos == END_BIT)

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

reset :: proc(using reader: ^BitReader) {
	it = stable_it
	bit_pos = FIRST_BIT
}

commit :: proc(using reader: ^BitReader) {
	assert(bit_pos == END_BIT || bit_pos == FIRST_BIT) // should not be in the middle of a byte

	if (bit_pos == END_BIT) {
		it += 1
		bit_pos = FIRST_BIT
	}

	stable_it = it
	bit_pos = FIRST_BIT
}

finished :: proc(using reader: ^BitReader) -> bool {
	overflowed := it >= cast(u64)len(data)
	end := (it + 1) == cast(u64)len(data) && bit_pos == END_BIT

	return overflowed || end
}
