
## question 1:
the class used to implement the controller for snapping_sheet is the SnappingSheetController.
this controller mainly allows the user to control the position of the snapping sheet.
for example we can find the current position of the snapping sheet,
and we can snap it to a new location.

## question 2:
the parameter used to control the snapping animation is the snappingCurve attribute.
for example :snappingCurve: Curves.easeInToLinear.
I used in this assignment.

## question 3:
the InkWell has ripple effect. which means, that while pressing we can see a growing effect of ink
spreading along the InkWell. while GestureDetector does not have this option.
the on the other hand GestureDetector can be controlled further then the InkWell,
for example we can use drag on GestureDetector and not on InkWell.