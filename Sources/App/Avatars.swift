//
//  Avatars.swift
//  App
//
//  Created by m.rakhmanov on 16.09.17.
//

import Foundation

final class Avatars {

    static let urlStrings: [String] = [
        "http://www.myextralife.com/wp-content/uploads/2009/11/steve-chicken.jpg",
        "https://cdn3.iconfinder.com/data/icons/avatars-9/145/Avatar_Cat-512.png",
        "http://statici.behindthevoiceactors.com/behindthevoiceactors/_img/chars/mr-peanutbutter-bojack-horseman-72.4.jpg",
        "https://pixel.nymag.com/imgs/daily/vulture/2016/07/21/bojack-horseman/21-bojack-12.w710.h473.2x.jpg",
        "https://i.pinimg.com/736x/44/6a/35/446a352fe24c3827d609f327ed6590f8--pusheen-cat-free-food.jpg",
        "https://vignette3.wikia.nocookie.net/worldsgreatestheroes/images/1/1d/Chewbacca_headshot.jpg",
        "https://static.spin.com/files/2016/03/Dean-Blunt-by-Press-compressed.jpg",
        "http://3.bp.blogspot.com/_gp0vNKvnftc/Sw2n2ImnEPI/AAAAAAAAAMc/_g_fbh92-LY/s1600/not+the+beees.png",
        "http://www.peoples.ru/character/literature/winnie-the-pooh/winnie-the-pooh_1.jpg",
        "http://stuffpoint.com/cats/image/295310-cats-angry-cat.jpg"
    ]

    static func random() -> String {
        let rand = arc4random_uniform(UInt32(urlStrings.count))
        return urlStrings[Int(rand)]
    }
}
