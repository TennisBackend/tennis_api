import Vapor
import FluentProvider
import HTTP

final class Team: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey = "id"
        static let gameIdKey = "game_id"
        static let gameScoreKey = "score"
    }

    var gameId: Identifier
    var score: Int

    /// Creates a new Post
    init(gameId: Identifier,
         score: Int = 0) {
        self.gameId = gameId
        self.score = score
    }

    var game: Parent<Team, Game> {
        return parent(id: gameId)
    }

    var slots: Children<Team, Slot> {
        return children()
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        gameId = try row.get(Team.Keys.gameIdKey)
        score = try row.get(Team.Keys.gameScoreKey)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Team.Keys.gameIdKey, gameId)
        try row.set(Team.Keys.gameScoreKey, score)
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
            builder.int(Team.Keys.gameScoreKey)
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
            gameId: json.get(Team.Keys.gameIdKey),
            score: json.get(Team.Keys.gameScoreKey)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Team.Keys.idKey, id)
        try json.set(Team.Keys.gameIdKey, gameId)
        try json.set(Team.Keys.gameScoreKey, score)
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




