import Vapor
import FluentProvider
import HTTP

final class Team: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey     = "id"
        static let gameIdKey = "game_id"
    }

    fileprivate(set) var gameId: Identifier

    /// Creates a new Post
    init(gameId: Identifier) {
        self.gameId = gameId
    }

    var game: Parent<Team, Game> {
        return parent(id: gameId)
    }

    var invitations: Children<Team, Invitation> {
        return children()
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        gameId = try row.get(Team.Keys.gameIdKey)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Team.Keys.gameIdKey, gameId)
        return row
    }
}

// MARK: Fluent Preparation

extension Team: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Posts
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.foreignId(for: Game.self)
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
extension Team: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            gameId: json.get(Team.Keys.gameIdKey)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Team.Keys.idKey, id)
        try json.set(Team.Keys.gameIdKey, gameId)
        return json
    }
}

extension Team: Timestampable { }

// MARK: HTTP

extension Team: ResponseRepresentable { }

extension Team: Updateable {

    static var updateableKeys: [UpdateableKey<Team>] {
        return [
            UpdateableKey(Team.Keys.gameIdKey, Identifier.self) { team, value in
                team.gameId = value
            }
        ]
    }
}




