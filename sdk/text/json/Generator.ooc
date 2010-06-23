import io/Writer
import structs/[Bag, HashBag]
import text/[Buffer, EscapeSequence]

import Parser

GeneratorError: class extends Exception {
    init: func ~withMsg (.msg) {
        super(msg)
    }
}

generate: func <T> (writer: Writer, obj: T) {
    match T {
        case String => {
            writer write("\"%s\"" format(EscapeSequence escape(obj as String)))
        }
        case Int => {
            writer write(obj as Int toString())
        }
        case Bool => {
            writer write((obj as Bool ? "true" : "false"))
        }
        case Pointer => {
            writer write("null")
        }
        case Number => {
            writer write(obj as Number value)
        }
        case HashBag => {
            writer write('{')
            bag := obj as HashBag
            first := true
            for(key: String in bag getKeys()) {
                if(first)
                    first = false
                else
                    writer write(',')
                generate(writer, key)
                writer write(':')
                U := bag getClass(key)
                generate(writer, bag get(key, U))
            }
            writer write('}')
        }
        case Bag => {
            writer write('[')
            bag := obj as Bag
            first := true
            for(i: SizeT in 0..bag size()) {
                if(first)
                    first = false
                else
                    writer write(',')
                U := bag getClass(i)
                generate(writer, bag get(i, U))
            }
            writer write(']')
        }
        case => {
            GeneratorError new("Unknown type: %s" format(T name)) throw()
        }
    }
}

generateString: func <T> (obj: T) -> String {
    writer := BufferWriter new()
    generate(writer, obj)
    writer buffer toString()
}
