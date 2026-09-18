import 'package:flutter/widgets.dart';

/// Width at which the app switches from bottom navigation to a sidebar.
const double kWideBreakpoint = 900;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
