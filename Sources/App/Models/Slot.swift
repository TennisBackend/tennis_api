//
//  Slot.swift
//  App
//
//  Created by m.rakhmanov on 15.09.17.
//

import Vapor
import FluentProvider
import HTTP

final class Slot: Model {
    let storage = Storage()

    // MARK: Properties and database keys

    /// The column names for `id` and `content` in the database
    struct Keys {
        static let idKey = "id"
        static let userIdKey = "user_id"
        static let teamIdKey = "team_id"
        static let isOpenKey = "is_open"
        static let isVacantKey = "is_vacant"
    }

    var isOpen: Bool
    var isVacant: Bool
    fileprivate(set) var userId: Identifier?
    fileprivate(set) var teamId: Identifier

    /// Creates a new Post
    init(userId: Identifier?,
         teamId: Identifier,
         isOpen: Bool,
         isVacant: Bool) {
        self.isOpen = isOpen
        self.isVacant = isVacant
        self.userId = userId
        self.teamId = teamId
    }

    var team: Parent<Slot, Team> {
        return parent(id: teamId)
    }

    var invitations: Children<Slot, Invitation> {
        return children()
    }

    // MARK: Fluent Serialization

    /// Initializes the Post from the
    /// database row
    init(row: Row) throws {
        isOpen = try row.get(Slot.Keys.isOpenKey)
        isVacant = try row.get(Slot.Keys.isVacantKey)
        teamId = try row.get(Slot.Keys.teamIdKey)
        userId = try? row.get(Slot.Keys.userIdKey)
    }

    // Serializes the Post to the database
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Slot.Keys.isOpenKey, isOpen)
        try row.set(Slot.Keys.isVacantKey, isVacant)
        do {
            try row.set(Slot.Keys.teamIdKey, teamId)
        } catch {}

        do {
            try row.set(Slot.Keys.userIdKey, userId)
        } catch {}
        return row
    }
}

// MARK: Fluent Preparation

extension Slot: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Posts
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.bool(Slot.Keys.isOpenKey)
            builder.bool(Slot.Keys.isVacantKey)
            builder.foreignId(for: User.self)
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
extension Slot: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            userId: json.get(Slot.Keys.userIdKey),
            teamId: json.get(Slot.Keys.teamIdKey),
            isOpen: json.get(Slot.Keys.isOpenKey),
            isVacant: json.get(Slot.Keys.isVacantKey)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Slot.Keys.idKey, id)
        try json.set(Slot.Keys.isVacantKey, isVacant)
        try json.set(Slot.Keys.isOpenKey, isOpen)
        try json.set(Slot.Keys.teamIdKey, teamId)
        return json
    }
}

extension Slot: Timestampable { }

// MARK: HTTP

// This allows Post models to be returned
// directly in route closures
extension Slot: ResponseRepresentable { }

extension Slot: Updateable {

    // Updateable keys are called when `post.update(for: req)` is called.
    // Add as many updateable keys as you like here.
    static var updateableKeys: [UpdateableKey<Slot>] {
        return [
            // If the request contains a String at key "content"
            // the setter callback will be called.

//            UpdateableKey(Slot.Keys.isOpenKey, Bool.self) { slot, value in
//                slot.isOpen = value
//            }
            UpdateableKey(Slot.Keys.isVacantKey, Bool.self) { slot, value in
                slot.isVacant = value
            }
        ]
    }
}




