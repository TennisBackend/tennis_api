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

            let teamCount = json["teamCount"]?.int as? Int ?? 1
            if teamCount == 1 {
                return try self.storeSingleGame(json: json, meId: user.id!)
            }

            fatalError()
        }
    }

    func storeSingleGame(json: JSON, meId: Identifier) throws -> Game {
        guard let partnerId = json["first"]?.string else {
            throw Abort(.badRequest, metadata: "Incorrect data for single game")
        }
        let game = Game(teamPlayers: 1,
                        startTime: Date(),
                        finished: false)

        try game.save()

        let firstTeam = Team(gameId: game.id!)
        let secondTeam = Team(gameId: game.id!)
        try firstTeam.save()
        try secondTeam.save()
        return game
    }
}
