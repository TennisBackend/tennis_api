import Vapor
import AuthProvider

extension Droplet {
    func setupRoutes() throws {
        try setupPasswordProtectedRoutes()
        try setupTokenProtectedRoutes()

        get("hello") { req in
            var json = JSON()
            try json.set("hello", "world")
            return json
        }

        get("plaintext") { req in
            return "Hello, world!"
        }

        // response to requests to /info domain
        // with a description of the request
        get("info") { req in
            return req.description
        }

        get("description") { req in return req.description }

        try resource("users", UserController.self)
        try resource("teams", TeamController.self)
    }

    /// Sets up all routes that can be accessed using
    /// username + password authentication.
    /// Since we want to minimize how often the username + password
    /// is sent, we will only use this form of authentication to
    /// log the user in.
    /// After the user is logged in, they will receive a token that
    /// they can use for further authentication.
    private func setupPasswordProtectedRoutes() throws {
        // creates a route group protected by the password middleware.
        // the User type can be passed to this middleware since it
        // conforms to PasswordAuthenticatable
        let password = grouped([
            PasswordAuthenticationMiddleware(User.self)
            ])

        // verifies the user has been authenticated using the password
        // middleware, then generates, saves, and returns a new access token.
        //
        // POST /login
        // Authorization: Basic <base64 email:password>
        password.post("login") { req in
            let user = try req.user()
            let token = try Token.generate(for: user)
            try token.save()
            return token
        }
    }

    /// Sets up all routes that can be accessed using
    /// the authentication token received during login.
    /// All of our secure routes will go here.
    private func setupTokenProtectedRoutes() throws {
        // creates a route group protected by the token middleware.
        // the User type can be passed to this middleware since it
        // conforms to TokenAuthenticatable
        let token = grouped([
            TokenAuthenticationMiddleware(User.self)
            ])

        // simply returns a greeting to the user that has been authed
        // using the token middleware.
        //
        // GET /me
        // Authorization: Bearer <token from /login>
        token.get("me") { req in
            let user = try req.user()
            return user
        }

        token.post("createGame") { req in
            guard var json = req.json else {
                throw Abort(.badRequest)
            }
            let user = try req.user()

            let teamCount = json["teamCount"]?.int ?? 1
            if teamCount == 1 {
                return try self.storeSingleGame(json: json, meId: user.id!)
            } else {
                return try self.storeDoubleGame(json: json, meId: user.id!)
            }
        }
    }

    func storeSingleGame(json: JSON, meId: Identifier) throws -> Game {
        guard let rivalIds = json["rivals"]?.array,
              let rivalId = rivalIds.first?.string else {
            throw Abort(.badRequest, metadata: "Incorrect data for single game")
        }
        let game = Game(teamPlayers: 1,
                        startTime: Date(),
                        status: "pending")

        try game.save()

        let firstTeam = Team(gameId: game.id!)
        try firstTeam.save()
        let firstSlot = Slot(userId: meId,
                             teamId: firstTeam.id!,
                             isOpen: false,
                             isVacant: false)
        try firstSlot.save()

        let secondTeam = Team(gameId: game.id!)
        try secondTeam.save()

        let userId = (rivalId == "all") ? nil : try User.find(rivalId)?.id
        let secondSlot = Slot(userId: userId,
                              teamId: secondTeam.id!,
                              isOpen: rivalId == "all",
                              isVacant: true)
        try secondSlot.save()
        let secondInvitation = Invitation(slotId: secondSlot.id!,
                                          allPlayersInvited: rivalId == "all")
        try secondInvitation.save()

        return game
    }

    func storeDoubleGame(json: JSON, meId: Identifier) throws -> Game {
        guard let rivalIdsArray = json["rivals"]?.array,
              let partner = json["partner"]?.string
            else {
                throw Abort(.badRequest, metadata: "Incorrect data for single game")
        }
        let rivalIds = rivalIdsArray.flatMap({ $0.string })

        guard rivalIds.count == 2 else {
            throw Abort(.badRequest, metadata: "Incorrect data for double game")
        }

        let game = Game(teamPlayers: 2,
                        startTime: Date(),
                        status: "pending")
        try game.save()

        let firstTeam = Team(gameId: game.id!)
        try firstTeam.save()
        let firstSlot = Slot(userId: meId,
                             teamId: firstTeam.id!,
                             isOpen: false,
                             isVacant: false)
        try firstSlot.save()

        let partnerId = (partner == "all") ? nil : try User.find(partner)?.id
        let partnerSlot = Slot(userId: partnerId,
                               teamId: firstTeam.id!,
                               isOpen: partner == "all",
                               isVacant: true)
        try partnerSlot.save()
        let partnerInvitation = Invitation(slotId: partnerSlot.id!,
                                           allPlayersInvited: partner == "all")
        try partnerInvitation.save()

        let secondTeam = Team(gameId: game.id!)
        try secondTeam.save()

        for rivalId in rivalIds {
            let userId = (rivalId == "all") ? nil : try User.find(rivalId)?.id
            let slot = Slot(userId: userId,
                            teamId: secondTeam.id!,
                            isOpen: rivalId == "all",
                            isVacant: true)
            try slot.save()
            let invitation = Invitation(slotId: slot.id!,
                                        allPlayersInvited: rivalId == "all")
            try invitation.save()
        }

        return game
    }
}
