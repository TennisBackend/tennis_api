import Vapor
import FluentProvider
import HTTP

final class Game: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey = "id"
        static let teamPlayers = "team_players"
        static let startTime = "start_time"
        static let status = "status"
        static let teamsKey = "teams"
    }

    var teamPlayers: Int
    var startTime: Date
    var status: String

    /// Creates a new Post
    init(teamPlayers: Int,
         startTime: Date,
         status: String) {
        self.teamPlayers = teamPlayers
        self.startTime = startTime
        self.status = status
    }

    var teams: Children<Game, Team> {
        return children()
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        teamPlayers = try row.get(Game.Keys.teamPlayers)
        startTime = try row.get(Game.Keys.startTime)
        status = try row.get(Game.Keys.status)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Game.Keys.teamPlayers, teamPlayers)
        try row.set(Game.Keys.startTime, startTime)
        try row.set(Game.Keys.status, status)
        return row
    }
}

// MARK: Fluent Preparation

extension Game: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Posts
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.int(Game.Keys.teamPlayers)
            builder.date(Game.Keys.startTime)
            builder.string(Game.Keys.status)
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
extension Game: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            teamPlayers: json.get(Game.Keys.teamPlayers),
            startTime: json.get(Game.Keys.startTime),
            status: json.get(Game.Keys.status)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Game.Keys.idKey, id)
        try json.set(Game.Keys.teamPlayers, teamPlayers)
        try json.set(Game.Keys.startTime, startTime)
        try json.set(Game.Keys.status, status)
        try json.set(Game.Keys.teamsKey, teams.all().makeJSON())
        return json
    }
}

extension Game: Timestampable { }

// MARK: HTTP

// This allows Post models to be returned
// directly in route closures
extension Game: ResponseRepresentable { }

extension Game: Updateable {

    // Updateable keys are called when `post.update(for: req)` is called.
    // Add as many updateable keys as you like here.
    static var updateableKeys: [UpdateableKey<Game>] {
        return [
            // If the request contains a String at key "content"
            // the setter callback will be called.
            UpdateableKey(Game.Keys.startTime, Date.self) { game, value in
                game.startTime = value
            },
            UpdateableKey(Game.Keys.status, String.self) { game, value in
                game.status = value
            }
        ]
    }
}



