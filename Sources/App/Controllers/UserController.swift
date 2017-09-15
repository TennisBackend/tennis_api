import Vapor
import HTTP

/// Here we have a controller that helps facilitate
/// RESTful interactions with our Posts table
final class UserController: ResourceRepresentable {
    /// When users call 'GET' on '/posts'
    /// it should return an index of all available posts
    func index(_ req: Request) throws -> ResponseRepresentable {
        return try User.all().makeJSON()
    }

    /// When consumers call 'POST' on '/posts' with valid JSON
    /// construct and save the post
    func store(_ req: Request) throws -> ResponseRepresentable {
        guard var json = req.json else {
            throw Abort(.badRequest)
        }
        json["rating"] = 1000.0
        let user = try User(json: json)

        // ensure no user with this email already exists
        guard try User.makeQuery().filter("email", user.email).first() == nil else {
            throw Abort(.badRequest, reason: "A user with that email already exists.")
        }

        // require a plaintext password is supplied
        guard let password = json["password"]?.string else {
            throw Abort(.badRequest)
        }

//        user.password = try self.hash.make(password.makeBytes()).makeString()

        try user.save()

        let token = try Token.generate(for: user)
        try token.save()
        return token
    }

    /// When the consumer calls 'GET' on a specific resource, ie:
    /// '/posts/13rd88' we should show that specific post
    func show(_ req: Request, user: User) throws -> ResponseRepresentable {
        return user
    }

    /// When the consumer calls 'DELETE' on a specific resource, ie:
    /// 'posts/l2jd9' we should remove that resource from the database
    func delete(_ req: Request, user: User) throws -> ResponseRepresentable {
        try user.delete()
        return Response(status: .ok)
    }

    /// When the consumer calls 'DELETE' on the entire table, ie:
    /// '/posts' we should remove the entire table
    func clear(_ req: Request) throws -> ResponseRepresentable {
        try User.makeQuery().delete()
        return Response(status: .ok)
    }

    /// When the user calls 'PATCH' on a specific resource, we should
    /// update that resource to the new values.
    func update(_ req: Request, user: User) throws -> ResponseRepresentable {
        // See `extension Post: Updateable`
        try user.update(for: req)

        // Save an return the updated post.
        try user.save()
        return user
    }

    /// When a user calls 'PUT' on a specific resource, we should replace any
    /// values that do not exist in the request with null.
    /// This is equivalent to creating a new Post with the same ID.
    func replace(_ req: Request, user: User) throws -> ResponseRepresentable {
        // First attempt to create a new Post from the supplied JSON.
        // If any required fields are missing, this request will be denied.
        let new = try req.user()

        // Update the post with all of the properties from
        // the new post
        user.name = new.name
        user.email = new.email
        user.password = new.password
        user.rating = new.rating
        try user.save()

        // Return the updated post
        return user
    }

    /// When making a controller, it is pretty flexible in that it
    /// only expects closures, this is useful for advanced scenarios, but
    /// most of the time, it should look almost identical to this
    /// implementation
    func makeResource() -> Resource<User> {
        return Resource(
            index: index,
            store: store,
            show: show,
            update: update,
            replace: replace,
            destroy: delete,
            clear: clear
        )
    }
}

/// Since PostController doesn't require anything to
/// be initialized we can conform it to EmptyInitializable.
///
/// This will allow it to be passed by type.
extension UserController: EmptyInitializable { }

