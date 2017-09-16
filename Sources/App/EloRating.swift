//
//  EloRating.swift
//  App
//
//  Created by m.rakhmanov on 16.09.17.
//

struct SingleMatchConfiguration {
    let rating: SingleMatchRating
    let firstScore: Double
    let secondScore: Double
}

struct SingleMatchRating {
    let winnerRating: Double
    let loserRating: Double
}

struct DoubleMatchRating {
    let firstWinnerRating: Double
    let secondWinnerRating: Double
    let firstLoserRating: Double
    let secondLoserRating: Double
}

struct DoubleMatchConfiguration {
    let rating: DoubleMatchRating
    let firstScore: Double
    let secondScore: Double
}

func updatedRatingForSingleMatch(configuration: SingleMatchConfiguration,
                                 k: Double) -> SingleMatchRating {

    func transformedRating(_ rating: Double) -> Double {
        return pow(10, rating / 400.0)
    }

    let firstRating = configuration.rating.winnerRating
    let secondRating = configuration.rating.loserRating
    let firstTransformed = transformedRating(firstRating)
    let secondTransformed = transformedRating(secondRating)
    let totalTransformed = firstTransformed + secondTransformed

    let firstExpectedRatio = firstTransformed / totalTransformed
    let secondExpectedRatio = secondTransformed / totalTransformed

    let totalScore = configuration.firstScore + configuration.secondScore
    let firstScoreRatio = configuration.firstScore / totalScore
    let secondScoreRatio = configuration.secondScore / totalScore

    let finalFirstRating = firstRating + k * (firstScoreRatio - firstExpectedRatio)
    let finalSecondRating = secondRating + k * (secondScoreRatio - secondExpectedRatio)

    return SingleMatchRating(winnerRating: finalFirstRating,
                             loserRating: finalSecondRating)
}

func updatedRatingForDoubleMatch(configuration: DoubleMatchConfiguration,
                                 k: Double) -> DoubleMatchRating {
    let winnerRatings = [configuration.rating.firstWinnerRating,
                         configuration.rating.secondWinnerRating]
    let loserRatings = [configuration.rating.firstLoserRating,
                        configuration.rating.secondLoserRating]

    var ratingDiffs: [Double] = []
    for (first, second) in zip(winnerRatings, loserRatings) {
        let matchConfiguration = SingleMatchConfiguration(rating: SingleMatchRating(winnerRating: first,
                                                                                    loserRating: second),
                                                          firstScore: configuration.firstScore,
                                                          secondScore: configuration.secondScore)
        let updatedRating = updatedRatingForSingleMatch(configuration: matchConfiguration, k: k)
        ratingDiffs.append(abs(updatedRating.winnerRating - updatedRating.loserRating))
    }

    for (first, second) in zip(winnerRatings, loserRatings.reversed()) {
        let matchConfiguration = SingleMatchConfiguration(rating: SingleMatchRating(winnerRating: first,
                                                                                    loserRating: second),
                                                          firstScore: configuration.firstScore,
                                                          secondScore: configuration.secondScore)
        let updatedRating = updatedRatingForSingleMatch(configuration: matchConfiguration, k: k)
        ratingDiffs.append(abs(updatedRating.winnerRating - updatedRating.loserRating))
    }

    let averageDiff = ratingDiffs.reduce(0, +) / Double(ratingDiffs.count)

    return DoubleMatchRating(firstWinnerRating: ceil(configuration.rating.firstWinnerRating + averageDiff),
                             secondWinnerRating: ceil(configuration.rating.secondWinnerRating + averageDiff),
                             firstLoserRating: ceil(configuration.rating.firstLoserRating - averageDiff),
                             secondLoserRating: ceil(configuration.rating.secondLoserRating - averageDiff))
}

