# Reference board refinement

This branch refines the board renderer against the supplied device reference.

- Place each pushpin at the rotated horizontal center of its photo card.
- Keep the pin needle entering the card at the top-center anchor.
- Render a thicker, clean red braided rope below the cards and pins.
- Remove green-screen fringe from rope and pin assets.
- Keep route order and card placement close to the supplied cork-board composition.
- Validate with an installed iOS Simulator app and `simctl io screenshot`.
