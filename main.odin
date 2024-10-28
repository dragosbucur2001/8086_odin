package emulator

import "core:fmt"
import "core:io"
import "core:os"


main :: proc() {
	// Check if a file name was provided
	if len(os.args) < 2 {
		fmt.println("Usage: ./8086 <filename>")
		return
	}

	// Get the file name from the command-line argument
	filename := os.args[1]

	// Read the entire file contents
	data, ok := os.read_entire_file_from_filename(filename)
	if !ok {
		fmt.println("Error reading file: ", filename)
		return
	}

	reader := init_bit_reader(data)


}
