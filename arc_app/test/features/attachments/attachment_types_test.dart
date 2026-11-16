import 'package:arc_app/features/attachments/attachment_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the picker offers the same types the server accepts', () {
    expect(attachmentExtensions, unorderedEquals(['mp3', 'wav', 'm4a', 'mp4', 'pdf']));
  });

  test('PDFs are documents; everything else is audio', () {
    expect(attachmentTypeFor('pdf'), 'pdf');
    expect(attachmentTypeFor('PDF'), 'pdf');
    expect(attachmentTypeFor('mp4'), 'audio');
    expect(attachmentTypeFor('m4a'), 'audio');
  });

  test('an mp4 plays as audio in the browser', () {
    expect(mimeTypeFor('Ensayo.MP4'), 'audio/mp4');
    expect(mimeTypeFor('voz.m4a'), 'audio/mp4');
    expect(mimeTypeFor('letra.pdf'), 'application/pdf');
    expect(mimeTypeFor('pista.mp3'), 'audio/mpeg');
    expect(mimeTypeFor('pista.wav'), 'audio/wav');
    expect(mimeTypeFor('raro.xyz'), 'application/octet-stream');
  });
}
