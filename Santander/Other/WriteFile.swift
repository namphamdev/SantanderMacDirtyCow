//
//  WriteFile.swift
//  Santander
//
//  Created by Mineek on 01/01/2023.
//

import Foundation
@_exported import FSOperations

func overwriteFile(fileDataLocked: Data, pathtovictim: String) -> Bool {
  var fileData = fileDataLocked
  let fd = open(pathtovictim, O_RDONLY | O_CLOEXEC)
  NSLog("Path to victim: \(pathtovictim)")
  if fd == -1 {
    print("can't open font?!")
    return false
  }
  defer { close(fd) }
  let originalFileSize = lseek(fd, 0, SEEK_END)
  guard originalFileSize >= fileData.count else {
    print("font too big!")
    return false
  }
  lseek(fd, 0, SEEK_SET)

  NSLog("data: \(fileData)")

  let fileMap = mmap(nil, fileData.count, PROT_READ, MAP_SHARED, fd, 0)
  if fileMap == MAP_FAILED {
    print("can't mmap font?!")
    return false
  }
  guard mlock(fileMap, fileData.count) == 0 else {
    print("can't mlock")
    return false
  }

  print(Date())
  for chunkOff in stride(from: 0, to: fileData.count, by: 0x4000) {
    print(String(format: "%lx", chunkOff))
    // we only rewrite 16383 bytes out of every 16384 bytes.
    let dataChunk = fileData[chunkOff..<min(fileData.count, chunkOff + 0x3fff)]
    var overwroteOne = false
    for _ in 0..<2 {
      let overwriteSucceeded = dataChunk.withUnsafeBytes { dataChunkBytes in
        return unaligned_copy_switch_race(
          fd, Int64(chunkOff), dataChunkBytes.baseAddress, dataChunkBytes.count)
      }
      if overwriteSucceeded {
        overwroteOne = true
        break
      }
      print("try again?!")
    }
    guard overwroteOne else {
      print("can't overwrite")
      return false
    }
  }
  print(Date())
  print("successfully overwrote everything")
  return true
}

struct RootConf: RootHelperConfiguration {
    var useRootHelper: Bool = true
    
    private init() {}
    
    static let shared = RootConf()
    
    func perform(_ operation: FSOperation) throws {
        switch operation {
        case .writeData(let url, let data):
            try overwriteFile(fileDataLocked: data, pathtovictim: url.path)
        case .writeString(let url, let string):
            try overwriteFile(fileDataLocked: string.data(using: .utf8)!, pathtovictim: url.path)
        default:
            break
        }
    }
    
    func contents(of path: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [])
    }
}
