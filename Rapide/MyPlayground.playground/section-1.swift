// Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

var lines: [String] = split(str) { $0 == " " }
// what's remaining to process
var zL: String = lines[0]

lines[0] = lineRemain + zL

