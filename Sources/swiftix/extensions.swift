extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Dictionary {
    subscript(key: Key, setDefault def: Value) -> Value {
        mutating get {
            if let value = self[key] {
                return value
            } else {
                self[key] = def
                return def
            }
        }
    }
}
