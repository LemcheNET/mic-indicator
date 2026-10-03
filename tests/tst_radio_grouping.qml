/*
 * Regression test for the config page's radio button grouping.
 *
 * Bug: QQC2.RadioButton is autoExclusive by default, and auto-exclusivity
 * groups every radio that shares a parent. configGeneral.qml puts the backend,
 * mute-scope and icon-size radios as direct children of one
 * Kirigami.FormLayout, which collapsed all three into a single exclusive group:
 * picking "Direct, via pactl" cleared the icon-size selection and vice versa.
 * A radio nested one level deeper (sizeFixed, inside a RowLayout) had the
 * opposite problem -- its own private group, so it never cleared its sibling.
 *
 * Fix: one explicit QQC2.ButtonGroup per logical group.
 *
 * TESTED. Passes under QtTest 6.4.2. Kirigami is not needed, so this runs
 * without a Plasma session:
 *
 *   QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_radio_grouping.qml
 *
 * Needs qml6-module-qtquick-{controls,templates,window,layouts},
 * qml6-module-qttest and qml6-module-qtqml-workerscript.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtTest

Item {
    width: 400
    height: 400

    // Reproduces the bug: six radios sharing one parent, plus one nested.
    Item {
        id: buggy

        QQC2.RadioButton { id: bA1; checked: true }
        QQC2.RadioButton { id: bA2 }
        QQC2.RadioButton { id: bB1; checked: true }
        QQC2.RadioButton { id: bB2 }
        QQC2.RadioButton { id: bC1; checked: true }
        RowLayout { QQC2.RadioButton { id: bC2 } }
    }

    // The shape configGeneral.qml now uses.
    Item {
        id: fixed

        QQC2.ButtonGroup { buttons: [fA1, fA2] }
        QQC2.ButtonGroup { buttons: [fB1, fB2] }
        QQC2.ButtonGroup { buttons: [fC1, fC2] }

        QQC2.RadioButton { id: fA1; checked: true }
        QQC2.RadioButton { id: fA2 }
        QQC2.RadioButton { id: fB1; checked: true }
        QQC2.RadioButton { id: fB2 }
        QQC2.RadioButton { id: fC1; checked: true }
        RowLayout { QQC2.RadioButton { id: fC2 } }
    }

    TestCase {
        name: "RadioGrouping"

        // Asserts the bug is real, so this test fails loudly if a future Qt
        // changes auto-exclusivity and the explicit groups become redundant.
        function test_a_shared_parent_clobbers() {
            bB2.checked = true;
            compare(bA1.checked, false,
                    "expected the shared-parent bug: a click in group B clears group A");
        }

        function test_b_explicit_groups_are_independent() {
            fB2.checked = true;
            compare(fA1.checked, true, "group A must be untouched");
            compare(fB1.checked, false, "group B first option must clear");
            compare(fB2.checked, true, "group B second option must set");
            compare(fC1.checked, true, "group C must be untouched");
        }

        // sizeFixed lives inside a RowLayout, so it has a different parent from
        // sizeAuto. Only an explicit group makes the pair exclusive.
        function test_c_nested_parent_still_exclusive() {
            fC2.checked = true;
            compare(fC1.checked, false, "nested-parent button must clear its sibling");
            compare(fC2.checked, true, "nested-parent button must set");
            compare(fA1.checked, true, "group A still untouched");
        }
    }
}
