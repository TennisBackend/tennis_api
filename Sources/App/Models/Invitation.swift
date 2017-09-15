import Vapor
import FluentProvider
import HTTP

final class Invitation: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey = "id"
        static let allPlayersInvitedKey = "all_players_invited"
        static let teamIdKey = "team_id"
    }

    var allPlayersInvited: Bool
    fileprivate(set) var teamId: Identifier

    /// Creates a new Post
    init(teamId: Identifier,
         allPlayersInvited: Bool) {
        self.allPlayersInvited = allPlayersInvited
        self.teamId = teamId
    }

    var team: Parent<Invitation, Team> {
        return parent(id: teamId)
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        allPlayersInvited = try row.get(Invitation.Keys.allPlayersInvitedKey)
        teamId = try row.get(Invitation.Keys.teamIdKey)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Invitation.Keys.allPlayersInvitedKey, allPlayersInvited)
        try row.set(Invitation.Keys.teamIdKey, teamId)
        return row
    }
}

// MARK: Fluent Preparation

extension Invitation: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Posts
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.bool(Invitation.Keys.allPlayersInvitedKey)
            builder.foreignId(for: Team.self)
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
extension Invitation: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            teamId: json.get(Invitation.Keys.teamIdKey),
            allPlayersInvited: json.get(Invitation.Keys.allPlayersInvitedKey)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Invitation.Keys.idKey, id)
        try json.set(Invitation.Keys.allPlayersInvitedKey, allPlayersInvited)
        try json.set(Invitation.Keys.teamIdKey, teamId)
        return json
    }
}

extension Invitation: Timestampable { }

// MARK: HTTP

// This allows Post models to be returned
// directly in route closures
extension Invitation: ResponseRepresentable { }

extension Invitation: Updateable {

    // Updateable keys are called when `post.update(for: req)` is called.
    // Add as many updateable keys as you like here.
    static var updateableKeys: [UpdateableKey<Invitation>] {
        return [
            // If the request contains a String at key "content"
            // the setter callback will be called.

            UpdateableKey(Invitation.Keys.allPlayersInvitedKey, Bool.self) { invitation, value in
                invitation.allPlayersInvited = value
            }
        ]
    }
}




