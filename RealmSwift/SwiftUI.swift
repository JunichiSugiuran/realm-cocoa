////////////////////////////////////////////////////////////////////////////
 //
 // Copyright 2021 Realm Inc.
 //
 // Licensed under the Apache License, Version 2.0 (the "License");
 // you may not use this file except in compliance with the License.
 // You may obtain a copy of the License at
 //
 // http://www.apache.org/licenses/LICENSE-2.0
 //
 // Unless required by applicable law or agreed to in writing, software
 // distributed under the License is distributed on an "AS IS" BASIS,
 // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 // See the License for the specific language governing permissions and
 // limitations under the License.
 //
 ////////////////////////////////////////////////////////////////////////////

#if canImport(SwiftUI)
import SwiftUI
import Combine
import Realm
import Realm.Private
import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private func createBinding<T: ThreadConfined, V>(_ getter: @escaping () -> T,
                                                 forKeyPath keyPath: ReferenceWritableKeyPath<T, V>) -> Binding<V> {
    let lastValue = getter()[keyPath: keyPath]
    return Binding(get: {
        let parent = getter()
        guard !parent.isInvalidated else {
            return lastValue
        }
        if parent.isFrozen {
            guard let thawed = parent.thaw() else {
                return lastValue
            }
            let value = thawed[keyPath: keyPath]
            return (value is ListBase) ? (value as! ThreadConfined).freeze() as! V : value
        }
        let value = parent[keyPath: keyPath]
        if let value = value as? ThreadConfined, !value.isInvalidated && value.realm != nil {
            return value.freeze() as! V
        }
        return value
    },
    set: { newValue in
        var parent = getter()
        guard !parent.isInvalidated else {
            return
        }
        if parent.isFrozen {
            guard let thawed = parent.thaw() else {
                return
            }
            parent = thawed
        }

        parent.realm?.beginWrite()
        parent[keyPath: keyPath] = newValue
        try! parent.realm?.commitWrite()
    })
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Binding where Value: ExpressibleByNilLiteral {
    /// :nodoc:
    public subscript<V, T>(dynamicMember member: ReferenceWritableKeyPath<V, T>) -> Binding<T> where Value == Optional<V>, V: ThreadConfined {
        get {
            createBinding({ wrappedValue! }, forKeyPath: member)
        }
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Binding where Value: ObjectBase & ThreadConfined {
    /// :nodoc:
    public subscript<V>(dynamicMember member: ReferenceWritableKeyPath<Value, V>) -> Binding<V> where V: _ManagedPropertyType {
        get {
            createBinding({ wrappedValue }, forKeyPath: member)
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Binding where Value: RealmCollection {
    /// :nodoc:
    public typealias Element = Value.Element
    /// :nodoc:
    public typealias Index = Value.Index
    /// :nodoc:
    public typealias Indices = Value.Indices
    /// :nodoc:
    public func filter(_ predicate: NSPredicate) -> Self {
        return Self(get: { wrappedValue.filter(predicate).freeze() as! Value }, set: { _ in })
    }
    /// :nodoc:
    public func remove<V>(at index: Index) where Value == List<V> {
        guard let collection = self.wrappedValue.thaw() else {
            return
        }
        try! collection.realm!.write {
            collection.remove(at: index)
        }
    }
    /// :nodoc:
    public func remove<V>(_ object: V) where Value == Results<V>, V: ObjectBase & ThreadConfined {
        guard let results = self.wrappedValue.thaw(),
              let thawed = object.thaw(),
              let index = results.index(of: thawed) else {
            return
        }
        try! results.realm!.write {
            results.realm!.delete(results[index])
        }
    }
    /// :nodoc:
    public func remove<V>(atOffsets offsets: IndexSet) where Value == Results<V>, V: ObjectBase {
        guard let results = self.wrappedValue.thaw() else {
            return
        }
        try! results.realm!.write {
            results.realm!.delete(Array(offsets.map { results[$0] }))
        }
    }
    /// :nodoc:
    public func remove<V>(atOffsets offsets: IndexSet) where Value: List<V> {
        guard let list = self.wrappedValue.thaw() else {
            return
        }
        try! list.realm!.write {
            list.remove(atOffsets: offsets)
        }
    }
    /// :nodoc:
    public func move<V>(fromOffsets offsets: IndexSet, toOffset destination: Int) where Value: List<V> {
        guard let list = self.wrappedValue.thaw() else {
            return
        }
        try! list.realm!.write {
            list.move(fromOffsets: offsets, toOffset: destination)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Element) where Value: List<V>, Value.Element: RealmCollectionValue {
        guard let list = self.wrappedValue.thaw() else {
            return
        }
        try! list.realm!.write {
            list.append(value)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Element) where Value: List<V>, Value.Element: ObjectBase & ThreadConfined {
        guard let list = self.wrappedValue.thaw() else {
            return
        }
        if value.realm == nil {
            observedObjects[value]?.cancel()
        }
        try! list.realm!.write {
            list.append(value)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Element) where Value == Results<V>, V: Object {
        let collection = self.wrappedValue.thaw()
        try! collection.realm!.write {
            collection.realm!.add(value)
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Binding where Value: ExpressibleByNilLiteral {
    /// :nodoc:
    public func remove<V>(at index: List<V>.Index) where Value == Optional<List<V>> {
        guard let collection = self.wrappedValue?.thaw() else {
            return
        }
        try! collection.realm!.write {
            collection.remove(at: index)
        }
    }
    /// :nodoc:
    public func remove<V>(at index: Results<V>.Index) where Value == Optional<Results<V>>, V: ObjectBase {
        guard let results = self.wrappedValue?.thaw() else {
            return
        }
        try! results.realm!.write {
            results.realm!.delete(results[index])
        }
    }
    /// :nodoc:
    public func remove<V>(atOffsets offsets: IndexSet) where Value == Optional<Results<V>>, V: ObjectBase {
        guard let results = self.wrappedValue?.thaw() else {
            return
        }
        try! results.realm!.write {
            results.realm!.delete(Array(offsets.map { results[$0] }))
        }
    }
    /// :nodoc:
    public func remove<V>(atOffsets offsets: IndexSet) where Value == Optional<List<V>> {
        guard let list = self.wrappedValue?.thaw() else {
            return
        }
        try! list.realm!.write {
            list.remove(atOffsets: offsets)
        }
    }
    /// :nodoc:
    public func move<V>(fromOffsets offsets: IndexSet, toOffset destination: Int) where Value == Optional<List<V>> {
        guard let list = self.wrappedValue?.thaw() else {
            return
        }
        try! list.realm!.write {
            list.move(fromOffsets: offsets, toOffset: destination)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Wrapped.Element) where Value == Optional<List<V>> {
        guard let list = self.wrappedValue?.thaw() else {
            return
        }
        try! list.realm!.write {
            list.append(value)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Wrapped.Element) where Value == Optional<Results<V>>, V: Object {
        guard let collection = self.wrappedValue?.thaw() else {
            return
        }
        try! collection.realm!.write {
            collection.realm!.add(value)
        }
    }
    /// :nodoc:
    public func index<V>(of value: V) -> Results<V>.Index? where Value == Optional<Results<V>>, V: Object {
        guard let collection = wrappedValue?.thaw() else {
            throwRealmException("Attempting to get index of value \(value) from nil Results")
        }
        return !value.thaw().isInvalidated ? collection.firstIndex(of: value.thaw()!) : nil
    }
}

// MARK: Realm Environment

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
public extension EnvironmentValues {
    /// The preferred Realm for the environment.
    /// If not set, this will be a Realm with the default configuration.
    var realm: Realm {
        get {
            try! Realm(configuration: Realm.Configuration.defaultConfiguration)
        }
        set {
            Realm.Configuration.defaultConfiguration = newValue.configuration
        }
    }
}

private final class OptionalNotificationToken: NotificationToken {
    override func invalidate() {
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Optional: RealmSubscribable where Wrapped: RealmSubscribable & ThreadConfined {

    struct WrappedSubscriber: Subscriber {
        typealias Input = Wrapped

        typealias Failure = Error

        var combineIdentifier: CombineIdentifier {
            subscriber.combineIdentifier
        }

        var subscriber: AnySubscriber<Optional<Wrapped>, Error>

        func receive(subscription: Subscription) {
            subscriber.receive(subscription: subscription)
        }

        func receive(_ input: Wrapped) -> Subscribers.Demand {
            subscriber.receive(input)
        }

        func receive(completion: Subscribers.Completion<Error>) {
            subscriber.receive(completion: completion)
        }
    }

    public func _observe<S>(on queue: DispatchQueue?,
                            _ subscriber: S) -> NotificationToken where Self == S.Input, S : Subscriber, S.Failure == Error {
        return self?._observe(on: queue, WrappedSubscriber(subscriber: AnySubscriber(subscriber))) ?? OptionalNotificationToken()
    }

    public func _observe<S>(_ subscriber: S) -> NotificationToken where S : Subscriber, S.Failure == Never, S.Input == Void {
        if self?.realm != nil {
            return self?._observe(subscriber) ?? OptionalNotificationToken()
        } else {
            return OptionalNotificationToken()
        }
    }
}

@available(iOS 9.0, macOS 10.9, tvOS 13.0, watchOS 6.0, *)
extension Optional: ThreadConfined where Wrapped: ThreadConfined {
    public var realm: Realm? {
        return self?.realm
    }

    public var isInvalidated: Bool {
        return self.map { $0.isInvalidated } ?? true
    }

    public var isFrozen: Bool {
        return self.map { $0.isFrozen } ?? false
    }

    public func freeze() -> Optional<Wrapped> {
        return self?.freeze()
    }

    public func thaw() -> Optional<Wrapped>? {
        return self?.thaw()
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private final class KVO: NSObject {
    private let _receive: () -> ()

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        _receive()
    }
    init<S>(subscriber: S) where S: Subscriber, S.Input == Void {
        _receive = { _ = subscriber.receive() }
        super.init()
    }
    func cancel() {
        print("cancel me")
    }
}
// MARK: - ObservableStorage
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public final class ObservableStoragePublisher<ObjectType>: Publisher where ObjectType: ThreadConfined & RealmSubscribable {
    public typealias Output = Void
    public typealias Failure = Never

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    private struct KVOSubscription: Subscription {
        let observer: NSObject
        let value: NSObject
        let keyPaths: [String]

        var combineIdentifier: CombineIdentifier {
            CombineIdentifier(value)
        }

        func request(_ demand: Subscribers.Demand) {
        }

        func cancel() {
            keyPaths.forEach {
                value.removeObserver(observer, forKeyPath: $0)
            }
        }
    }

    private var subscribers = [AnySubscriber<Void, Never>]()
    private let value: ObjectType
    internal init(_ value: ObjectType) {
        self.value = value
    }
    func send() {
        subscribers.forEach {
            _ = $0.receive()
        }
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscribers.append(AnySubscriber(subscriber))
        if value.realm != nil, let value = value.thaw() {
            let token =  value._observe(subscriber)
            subscriber.receive(subscription: ObservationSubscription(token: token))
        } else if let value = value as? ObjectBase, !value.isInvalidated {
            var outCount = UInt32(0)

            let propertyList = class_copyPropertyList(ObjectType.self as? AnyClass, &outCount)
            let kvo = KVO(subscriber: subscriber)
            var keyPaths = [String]()
            for index in 0..<outCount {
                let property = class_getProperty(ObjectType.self as? AnyClass,
                                                 property_getName(propertyList!.advanced(by: Int(index)).pointee))
                let name = String(cString: property_getName(property!))
                keyPaths.append(name)
                value.addObserver(kvo, forKeyPath: name, options: .new, context: nil)
            }
            subscriber.receive(subscription: KVOSubscription(observer: kvo, value: value, keyPaths: keyPaths))
            free(propertyList)
        } else /* nil value */ {
            subscriber.receive(subscription: ObservationSubscription(token: OptionalNotificationToken()))
        }
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private class ObservableStorage<ObservedType>: ObservableObject where ObservedType: RealmSubscribable & ThreadConfined & Equatable {
    @Published var value: ObservedType {
        willSet {
            if newValue != value {
                print("New Value!")
                objectWillChange.send()
            }
        }
    }
    var objectWillChange: ObservableStoragePublisher<ObservedType>
//    {
//         return ObservableStoragePublisher(self.value)
//    }

    init(_ value: ObservedType) {
        self.value = value.realm != nil ? value.thaw() ?? value : value
        self.objectWillChange = ObservableStoragePublisher(value)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private var observedObjects = [NSObject: KVO]()

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private struct ObserverSubscription: Subscription {
    let observer: NSObject
    let value: NSObject
    let keyPaths: [String]
    var combineIdentifier: CombineIdentifier {
        CombineIdentifier(value)
    }

    func request(_ demand: Subscribers.Demand) {
    }

    func cancel() {
        keyPaths.forEach {
            value.removeObserver(observer, forKeyPath: $0)
        }
    }
}

// MARK: - StateRealmObject
/**
 RealmState is a property wrapper that abstracts Realm's unique functionality away from the user and SwiftUI
 to enable simpler realm writes, collection freezes/thaws, and observation.

 SwiftUI will update views automatically when a wrapped value changes.

 Example usage:
 
 ```swift
 struct PersonView: View {
     @RealmState(Person.self) var results

     var body: some View {
         return NavigationView {
             List {
                 ForEach(results) { person in
                     NavigationLink(destination: PersonDetailView(person: person)) {
                         Text(person.name)
                     }
                 }
                 .onDelete(perform: $results.remove)
             }
             .navigationBarTitle("People", displayMode: .large)
             .navigationBarItems(trailing: Button("Add") {
                 $results.append(Person())
             })
         }
     }
 }
 ```
 */
@available(iOS 14.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
@frozen @propertyWrapper public struct StateRealmObject<T: RealmSubscribable & ThreadConfined & Equatable>: DynamicProperty {
    @StateObject private var storage: ObservableStorage<T>
    private let defaultValue: T

    /// :nodoc:
    public var wrappedValue: T {
        get {
            if storage.value.realm == nil {
                return storage.value
            } else if storage.value.isInvalidated {
                return defaultValue
            }
            if T.self is ObjectBase.Type {
                return storage.value
            }
            return storage.value.freeze()
        }
        nonmutating set {
            storage.value = newValue
        }
    }
    /// :nodoc:
    public var projectedValue: Binding<T> {
        Binding(get: {
            if storage.value.realm == nil {
                return storage.value
            }
            if storage.value.isInvalidated {
                return defaultValue
            }
            return storage.value.freeze()
        }, set: { newValue in
            storage.value = newValue
        })
    }
    /**
     Initialize a RealmState struct for a given thread confined type.
     - parameter wrappedValue The List reference to wrap and observe.
     */
    public init<Value>(wrappedValue: T) where T == List<Value> {
        self._storage = StateObject(wrappedValue: ObservableStorage(wrappedValue))
        defaultValue = T()
    }
    /**
     Initialize a RealmState struct for a given thread confined type.
     - parameter wrappedValue The ObjectBase reference to wrap and observe.
     */
    public init(wrappedValue: T) where T: ObjectBase {
        self._storage = StateObject(wrappedValue: ObservableStorage(wrappedValue))
        defaultValue = T()
    }
    /**
     Initialize a RealmState struct for a given thread confined type.
     - parameter wrappedValue The Results value to wrap and observe.
     */
    public init<V>(wrappedValue: T) where T == Results<V>, V: ObjectBase {
        self._storage = StateObject(wrappedValue: ObservableStorage(wrappedValue))
        defaultValue = wrappedValue
    }
    /**
     Initialize a StateRealmObject wrapper for a given optional value.
     - parameter wrappedValue The optional value to wrap.
     */
    public init<Wrapped>(wrappedValue: T) where T == Optional<Wrapped>, Wrapped: ThreadConfined & RealmSubscribable {
//        self.init()
        self._storage = StateObject(wrappedValue: ObservableStorage(wrappedValue))
        self.defaultValue = nil
    }

    /**
     Initialize a RealmState struct for a given Result type.
     - parameter type The Object Type to get results for.
     - parameter filter An optional filter to filter the results on.
     - parameter realm An optional realm to get the results from. If not provided, it will use the default Realm.
     */
    public init<U: Object>(_ type: U.Type, filter: NSPredicate? = nil, realm: Realm? = nil) where T == Results<U> {
        let actualRealm = realm == nil ? try! Realm(configuration: Realm.Configuration.defaultConfiguration) : realm!
        let results = filter == nil ? actualRealm.objects(U.self) : actualRealm.objects(U.self).filter(filter!)
        self._storage = StateObject(wrappedValue: ObservableStorage(results))
        self.defaultValue = results
    }

    public init<Wrapped>() where T == Optional<Wrapped>, Wrapped: ThreadConfined & RealmSubscribable {
        self._storage = StateObject(wrappedValue: ObservableStorage(nil))
        self.defaultValue = nil
    }
}

// MARK: ObservedRealmObject
@available(iOS 14.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
@frozen @propertyWrapper public struct ObservedRealmObject<ObjectType: RealmSubscribable & ThreadConfined & ObservableObject & Equatable>: DynamicProperty {
    /// A wrapper of the underlying observable object that can create bindings to
    /// its properties using dynamic member lookup.
    @dynamicMemberLookup @frozen public struct Wrapper {
        fileprivate var wrappedValue: ObjectType
        /// Returns a binding to the resulting value of a given key path.
        ///
        /// - Parameter keyPath  : A key path to a specific resulting value.
        ///
        /// - Returns: A new binding.
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            createBinding({wrappedValue}, forKeyPath: keyPath)
        }
    }
    /// The object to observe.
    @ObservedObject private var storage: ObservableStorage<ObjectType>
    /// A default value to avoid invalidated access
    private let defaultValue: ObjectType

    /// :nodoc:
    public var wrappedValue: ObjectType {
        get {
            if storage.value.realm == nil {
                // if unmangaged, return the unmanaged value
                return storage.value
            } else if storage.value.isInvalidated {
                // if invalidated, return the default value
                return defaultValue
            }
            // else return the frozen value. the frozen value
            // will be consumed by SwiftUI, which requires
            // the ability to cache and diff objects and collections
            // during some timeframe. the ObjectType is frozen so that
            // SwiftUI can cache state. other access points will thaw
            // the ObjectType
            return storage.value.freeze()
        }
        set {
            storage.value = newValue
        }
    }
    /// :nodoc:
    public var projectedValue: Wrapper {
        if storage.value.realm == nil {
            return Wrapper(wrappedValue: storage.value)
        } else if storage.value.isInvalidated {
            return Wrapper(wrappedValue: defaultValue)
        }
        if ObjectType.self is ObjectBase.Type {
            return Wrapper(wrappedValue: storage.value)
        }
        return Wrapper(wrappedValue: storage.value.freeze())
    }
    /**
     Initialize a RealmState struct for a given thread confined type.
     - parameter wrappedValue The RealmSubscribable value to wrap and observe.
     */
    public init(wrappedValue: ObjectType) where ObjectType: ObjectKeyIdentifiable {
        _storage = ObservedObject(wrappedValue: ObservableStorage(wrappedValue))
        defaultValue = ObjectType()
    }
    /**
     Initialize a RealmState struct for a given thread confined type.
     - parameter wrappedValue The RealmSubscribable value to wrap and observe.
     */
    public init<V>(wrappedValue: ObjectType) where ObjectType == List<V> {
        _storage = ObservedObject(wrappedValue: ObservableStorage(wrappedValue))
        defaultValue = List()
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
extension ObservedRealmObject.Wrapper where ObjectType: RealmCollection {
    public typealias Value = ObjectType
    /// :nodoc:
    public typealias Element = Value.Element
    /// :nodoc:
    public typealias Index = Value.Index
    /// :nodoc:
    public typealias Indices = Value.Indices
    /// :nodoc:
    public func remove<V>(at index: Index) where Value == List<V> {
        guard let collection = self.wrappedValue.thaw() else { return }
        try! collection.realm!.write {
            collection.remove(at: index)
        }
    }
    /// :nodoc:
    public func remove<V>(atOffsets offsets: IndexSet) where Value: List<V> {
        guard let list = self.wrappedValue.thaw() else { return }
        try! list.realm!.write {
            list.remove(atOffsets: offsets)
        }
    }
    /// :nodoc:
    public func move<V>(fromOffsets offsets: IndexSet, toOffset destination: Int) where Value: List<V> {
        guard let list = self.wrappedValue.thaw() else {
            return
        }
        try! list.realm!.write {
            list.move(fromOffsets: offsets, toOffset: destination)
        }
    }
    /// :nodoc:
    public func append<V>(_ value: Value.Element) where Value: List<V> {
        guard let list = self.wrappedValue.thaw() else { return }
        try! list.realm!.write {
            list.append(value)
        }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
extension ThreadConfined where Self: ObjectBase {
    /**
     Create a `Binding` for a given property, allowing for
     automatically transacted reads and writes behind the scenes.

     This is a convenience method for SwiftUI views (e.g., TextField, DatePicker)
     that require a `Binding` to be passed in. SwiftUI will automatically read/write
     from the binding.

     - parameter keyPath The key path to the member property.
     - returns A `Binding` to the member property.
     */
    public func bind<V: _ManagedPropertyType>(_ keyPath: ReferenceWritableKeyPath<Self, V>) -> Binding<V>  {
        createBinding({self}, forKeyPath: keyPath)
    }
}
#endif
