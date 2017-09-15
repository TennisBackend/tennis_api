import Vapor
import FluentProvider
import HTTP

final class User: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey      = "id"
        static let name       = "username"
        static let email      = "email"
        static let password   = "password"
        static let rating     = "rating"
    }

    var name: String
    var email: String
    var password: String
    var rating: Float

    /// Creates a new Post
    init(name: String,
         email: String,
         password: String,
         rating: Float) {
        self.name = name
        self.email = email
        self.password = password
        self.rating = rating
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        name = try row.get(User.Keys.name)
        email = try row.get(User.Keys.email)
        password = try row.get(User.Keys.password)
        rating = try row.get(User.Keys.rating)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(User.Keys.name, name)
        try row.set(User.Keys.email, email)
        try row.set(User.Keys.password, password)
        try row.set(User.Keys.rating, rating)
        return row
    }
}

// MARK: Fluent Preparation

extension User: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Posts
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(User.Keys.name)
            builder.string(User.Keys.email)
            builder.string(User.Keys.password)
            builder.float(User.Keys.rating)
        }
    }

    /// Undoes what was done in `prepare`
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: JSON

// How the model converts from / to JSON.
// For example when:
//     - Creating a new Post (POST /posts)
//     - Fetching a post (GET /posts, GET /posts/:id)
//
extension User: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            name: json.get(User.Keys.name),
            email: json.get(User.Keys.email),
            password: json.get(User.Keys.password),
            rating: json.get(User.Keys.rating)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(User.Keys.idKey, id)
        try json.set(User.Keys.name, name)
        try json.set(User.Keys.email, email)
        try json.set(User.Keys.password, password)
        try json.set(User.Keys.rating, rating)
        return json
    }
}

extension User: Timestampable { }

// MARK: HTTP

// This allows Post models to be returned
// directly in route closures
extension User: ResponseRepresentable { }

