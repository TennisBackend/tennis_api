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

        token.get("game") { req in
            guard let string = req.uri.query?.components(separatedBy: "gameId=").last else {
                throw Abort(.badRequest, metadata: "NoGameId")
            }

            guard let game = try Game.find(string) else {
                throw Abort(.badRequest, metadata: "Game Id Incorrect")
            }
            var json = JSON()
            var response: [String: Any] = [:]
            response["status"] = game.status
            response["teamPlayers"] = game.teamPlayers
            let teams = try game.teams.all()
            var teamArray: [[String: Any]] = []
            for team in teams {
                var teamElement: [String: Any] = [:]
                teamElement["teamId"] = team.id ?? ""
                let slots = try team.slots.all()
                let jsonSlots = try slots.map { try $0.makeJSON() }
                teamElement["slots"] = jsonSlots
                teamArray.append(teamElement)
            }
            response["teams"] = teamArray
            try json.set("response", response)
            return json
        }

        token.post("accept_slot") { req in
            guard let string = req.uri.query?.components(separatedBy: "slotId=").last else {
                throw Abort(.badRequest, metadata: "NoSlotId")
            }

            guard let slot = try Slot.find(string) else {
                throw Abort(.badRequest, metadata: "Slot Id Incorrect")
            }

            let user = try req.user()

            if (slot.userId == user.id || slot.isOpen) && slot.isVacant {
                slot.isVacant = false
                slot.userId = user.id
                try slot.save()
                let invitations = try slot.invitations.all()
                try invitations.forEach {
                    try $0.delete()
                }
                if let gameId = try slot.team.get()?.gameId, try self.noSlotsAreVacant(gameId: gameId) {
                    let game = try Game.find(gameId)
                    game?.status = "confirmed"
                    try game?.save()
                }

                return "All's cool"
            } else {
                throw Abort(.badRequest, metadata: "Cannot accept slot")
            }
        }

        token.post("set_game_score") { req in
            guard var json = req.json
                else {
                    throw Abort(.badRequest)
            }
            guard let teamsArray = json["teams"]?.array,
                  let gameId = json["gameId"]?.string,
                  let firstTeamId = teamsArray.first?["teamId"]?.string,
                  let firstTeamScore = teamsArray.first?["score"]?.int,
                  let secondTeamId = teamsArray.first?["teamId"]?.string,
                  let secondTeamScore = teamsArray.first?["score"]?.int
                else {
                    throw Abort(.badRequest)
            }

            let winnerTeamId = firstTeamScore > secondTeamScore ? firstTeamId : secondTeamId
            let loserTeamId = firstTeamScore > secondTeamScore ? secondTeamId : firstTeamId
            let loserScore = Double(min(firstTeamScore, secondTeamScore))
            let winnerScore = Double(max(firstTeamScore, secondTeamScore))

            if let game = try Game.find(gameId) {
                game.status = "finished"
                if game.teamPlayers == 1 {
                    try self.update1x1PlayersRating(winnerTeamId: Identifier(winnerTeamId),
                                                    loserTeamId: Identifier(loserTeamId),
                                                    winnerScore: winnerScore,
                                                    loserScore: loserScore)
                } else {
                    try self.update2x2PlayersRating(winnerTeamId: Identifier(winnerTeamId),
                                                    loserTeamId: Identifier(loserTeamId),
                                                    winnerScore: winnerScore,
                                                    loserScore: loserScore)
                }
                try game.save()
            }

            let firstTeam = try Team.find(firstTeamId)
            let secondTeam = try Team.find(secondTeamId)
            firstTeam?.score = firstTeamScore
            secondTeam?.score = secondTeamScore
            try firstTeam?.save()
            try secondTeam?.save()

            return "All's cool"
        }

        token.post("create_game") { req in
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

    func update2x2PlayersRating(winnerTeamId: Identifier,
                                loserTeamId: Identifier,
                                winnerScore: Double,
                                loserScore: Double) throws {
        guard let winnerIds = try Team.find(winnerTeamId)?.slots.all().flatMap { $0.userId },
            let loserIds = try Team.find(loserTeamId)?.slots.all().flatMap { $0.userId },
            loserIds.count == 2,
            winnerIds.count == 2 else {
                throw Abort(.badRequest)
        }
        let winners = try winnerIds.flatMap(User.find)
        let losers = try loserIds.flatMap(User.find)

        let rating = DoubleMatchRating(firstWinnerRating: winners.first!.rating,
                                       secondWinnerRating: winners.last!.rating,
                                       firstLoserRating: losers.first!.rating,
                                       secondLoserRating: losers.last!.rating)
        let configuration = DoubleMatchConfiguration(rating: rating,
                                                     firstScore: winnerScore,
                                                     secondScore: loserScore)

        let updatedRating = updatedRatingForDoubleMatch(configuration: configuration, k: 32.0)

        winners.first!.rating = updatedRating.firstWinnerRating
        winners.last!.rating = updatedRating.secondWinnerRating
        losers.first!.rating = updatedRating.firstLoserRating
        losers.last!.rating = updatedRating.secondLoserRating
        try winners.forEach {
            try $0.save()
        }
        try losers.forEach {
            try $0.save()
        }
    }

    func update1x1PlayersRating(winnerTeamId: Identifier,
                                loserTeamId: Identifier,
                                winnerScore: Double,
                                loserScore: Double) throws {
        guard let winnerId = try Team.find(winnerTeamId)?.slots.all().flatMap({ $0.userId }).first,
              let loserId = try Team.find(loserTeamId)?.slots.all().flatMap({ $0.userId }).first,
              let winner = try User.find(winnerId),
              let loser = try User.find(loserId)
            else {
                throw Abort(.badRequest)
        }
        let rating = SingleMatchRating(winnerRating: winner.rating, loserRating: loser.rating)
        let configuration = SingleMatchConfiguration(rating: rating, firstScore: winnerScore, secondScore: loserScore)
        let updatedRating = updatedRatingForSingleMatch(configuration: configuration, k: 32.0)
        winner.rating = updatedRating.winnerRating
        loser.rating = updatedRating.loserRating
        try winner.save()
        try loser.save()
    }

    func noSlotsAreVacant(gameId: Identifier?) throws -> Bool {
        guard let game = try Game.find(gameId) else {
            throw Abort(.badRequest, metadata: "Cannot find game while updating slots")
        }

        let teams = try game.teams.all()
        let slots = try teams.flatMap { try $0.slots.all() }

        return slots.first(where: { $0.isVacant }) == nil
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
