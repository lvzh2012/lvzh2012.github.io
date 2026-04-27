+++
date = '2026-03-03T17:03:15+08:00'
draft = false
title = 'Swift Extention'
tags = ["Swift", "Extension"]
categories = ["iOS 开发"]
cover = "https://d-image.i4.cn/i4web/image//upload/20190227/1551233745646040866.jpg"

+++

## Extension

### Codable Protocol

```swift
protocol CodableStorage {
    func saveCodable<T: Codable>(_ object: T, forKey key: String) throws
    func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T
}
// Use
// Use
extension UserDefaults: CodableStorage {
    func saveCodable<T>(_ object: T, forKey key: String) throws where T: Decodable, T: Encodable {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        let data = try e.encode(object)
        set(data, forKey: key)
    }

    func loadCodable<T>(_ type: T.Type, forKey key: String) throws -> T where T: Decodable, T: Encodable {
        guard let data = data(forKey: key) else {
            throw NSError(domain: "CodableStorageErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "key is not found"])
        }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(type, from: data)
    }
}
```

### Optional

```swift
extension Optional {
    func apply(_ closure: (Wrapped) -> Void) {
        if let wrappedValue = self {
            closure(wrappedValue)
        }
    }

    func apply(_ closure: (Wrapped) throws -> Void) throws {
        if let wrappedValue = self {
            try closure(wrappedValue)
        }
    }

    func apply<Result>(_ closure: (Wrapped) -> Result) -> Result? {
        if let wrappedValue = self {
            return closure(wrappedValue)
        }
        return nil
    }

    func apply<Result>(_ closure: (Wrapped) throws -> Result) throws -> Result? {
        if let wrappedValue = self {
            return try closure(wrappedValue)
        }
        return nil
    }
}
```

### Collection

```swift
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```
