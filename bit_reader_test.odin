package emulator

import "core:testing"

t :: testing

@(test)
test1 :: proc(test: ^t.T) {
	data := []u8{0b11001001, 0b00101100}
	reader := init_bit_reader(data[:])

	bits := read_bits(&reader, 4)
	t.expect(test, bits == 0b1100)

	bits = read_bits(&reader, 2)
	t.expect(test, bits == 0b10)

	bits = read_bits(&reader, 5)
	t.expect(test, bits == 0b01001)
}
