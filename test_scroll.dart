import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  var p = PdfViewerController();
  try {
    // try to call jumpTo
    // @ts-ignore
    p.jumpTo(xOffset: 0, yOffset: 0);
  } catch (e) {}
}
