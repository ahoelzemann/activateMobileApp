import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/persistant/Participant.dart';


class FAQ extends StatelessWidget {
  var pdfTextNonBCT = new RichText(
    textAlign: TextAlign.left,
    text: new TextSpan(
      style: new TextStyle(
        fontSize: 14.0,
        color: Colors.black,
      ),
      children: <TextSpan>[
        new TextSpan(
            text: '\u2160. Display des Bangles\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                '1.)	Was zeigt der Bangle an?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Das Fitnessarmband zeigt in der Mitte des Displays die Uhrzeit an. Darunter ist das Datum abzulesen. '
                    'Die drei Kreise oberhalb der Uhrzeit zeigen den Akkustand, die gelaufenen Schritte und '
                    'die aktiven Minuten an. Der gelbe Kreis oben links zeigt den Akkustand an. Während der '
                    'Bangle geladen wird, erscheint anstelle des Batteriesymbols ein Ladesteckersymbol und der '
                    'Akkustand steigt an. Der blaue Kreis, welcher sich oben mittig befindet, zeigt die '
                    'gelaufenen Schritte an. Bei einer Schrittzahl von über 10.000 werden die weiteren '
                    'Schritte gekürzt angezeigt: z.B. 10.300 Schritte ist gleich 10,3 k. Der rote Kreis '
                    'oben rechts zeigt die Aktivität in Minuten an.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '2.)	Ich bin gerade ein paar Schritte gegangen, aber die Schrittzahl verändert sich nicht. Woran liegt das?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Der Bangle zeichnet Schritte erst auf, nachdem ein paar Schritte direkt nacheinander erfolgt sind. '
                    'Kurze Strecken von 3 - 4 Schritten bleiben somit unaufgezeichnet um keine willkürlichen Bewegungen '
                    'als Schritte abzubilden. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '3.)	Wie erkenne ich, ob die Aufnahme gestartet ist? \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Sobald die Aufnahme korrekt gestartet ist, werden zwischen '
                    'der Uhrzeit und dem Datum sich verändernde Zahlenkombinationen '
                    'angezeigt, die lediglich aussagen, dass die Aufnahme funktioniert.  \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '4.)	Wie erkenne ich, ob der Upload der Daten funktioniert? \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Der Upload der Daten beginnt damit, dass in der App der Button „Ladezyklus“ '
                    'angeklickt und eine Startzeit für den nächsten Tag ausgewählt wird. '
                    'Beim Upload der Dateien werden die Punkte zwischen der Uhrzeit türkis angezeigt, '
                    'so können Sie sicherstellen, dass eine Bluetooth-Verbindung hergestellt wurde und '
                    'Daten übertragen werden. Während des Uploads ist das Display des Bangles inaktiv und '
                    'schwarz (es schaltet sich auch nicht über die Knöpfe an.) Dies hängt damit zusammen, '
                    'dass der Bangle mit dem Upload beschäftigt ist und der Bangle dann nicht genutzt werden kann.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '5.)	Was bedeutet ein schwarzer Bildschirm?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Ein schwarzer Bildschirm kann bedeuten, dass der Akku leer ist oder dass der Upload der Daten läuft.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '6.)	Welche Funktionen haben die Knöpfe?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Mit dem oberen und unteren Knopf schalten Sie das Display an und aus. Der mittlere Knopf hat keine Funktion.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '\u2161. Tragen des Bangles: \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                '1.)	Wie ist der Bangle zu tragen?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text: 'Der Bangle sollte am nicht-dominanten Handgelenk, für die Zeit direkt nach dem Aufstehen bis zum Zubettgehen getragen werden. '
                'Schließen Sie abends dann sowohl das Smartphone/Tablet, als auch der Bangle zum Laden an den Strom an. '
                'Lassen Sie die Geräte über Nacht dicht beieinander liegen. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '2.) Ist der Bangle wasserfest?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text: 'Der Bangle ist bis zu 10 Metern Wassertiefe wasserfest, was bedeutet, '
                'dass Sie den Bangle auch beim Duschen, Abwaschen oder Schwimmen gehen tragen können. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '\u2162. Laden des Bangles\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text: '1.)	Worauf muss ich beim Laden des Bangles achten?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Achten Sie beim Laden darauf, dass das Ladekabel von der ‚Knopfseite‘ eingesteckt wird, '
                    'da nur dann der Bangle korrekt auflädt. Legen Sie ihren Bangle zum Laden am besten zurück in '
                    'die Verpackung, damit das Ladekabel und der Bangle stabilisiert werden. Wir empfehlen, das '
                    'Laden und den Upload am Ende des Tages gleichzeitig durchzuführen. Nur wenn Sie das Smartphone '
                    'in direkter Nähe zu (im besten Fall neben) der Bangle platzieren, kann eine einwandfreie Datenübertragung gewährleistet werden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '2.)	Wie erkenne ich, dass der Bangle richtig lädt?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Wenn das Ladegerät korrekt angeschlossen ist, '
                    'dann verändert sich der Ladestand stetig und das'
                    ' Symbol in dem gelben Kreis verändert sich von '
                    'einem Blitz in einen Ladestecker.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '\u2163. App\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                '1.)	Worauf muss ich beim Nutzen der App achten?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Stellen Sie sicher, dass Bluetooth im Smartphone eingeschaltet ist '
                    'und Ihren Bangle sich in unmittelbarer Nähe befindet. Sollte sich '
                    'die App nicht korrekt öffnen, schließen Sie diese und öffnen '
                    'Sie die App erneut. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '2.)	Wie starte ich den Upload?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'Am Ende des Tages öffnen Sie die App „Trac2Move“ und klicken '
                    'auf das grüne Feld („Ladezyklus“) oben auf der Startseite '
                    'der App. Anschließend können Sie den Beginn der Aufnahme '
                    'für den nächsten Tag auswählen und der Upload der Daten startet. '
                    'Sie können den Bangle und das Smartphone/Tablet nun zum Aufladen '
                    'an den Strom anschließen und nebeneinanderlegen. Bitte wählen '
                    'Sie als Startzeit eine Zeit kurz vor Ihrer geplanten Aufstehzeit.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '3.)	Welche Einstellungen gibt es in der App?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
                'In der App können Sie die Daten übertragen und sehen, wie viele Schritte und aktive Minuten Sie am Tag absolviert haben. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '4.)	Warum startet meine Aufnahme nicht?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Achten Sie beim Einstellen der Aufnahmezeit darauf, dass der Startzeitpunkt in der Zukunft liegt. '
                'Am besten wählen Sie eine Uhrzeit kurz vor dem Aufstehen am nächsten Tag, damit gesichert ist, '
                'dass die Bluetooth-Verbindung zwischen Bangle und Smartphone/Tablet bestehen kann. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
      ],
    ),
  );

  var pdfTextBCT = new RichText(
    textAlign: TextAlign.left,
    text: new TextSpan(
      // Note: Styles for TextSpans must be explicitly defined.
      // Child text spans will inherit styles from parent
      style: new TextStyle(
        fontSize: 14.0,
        color: Colors.black,
      ),
      children: <TextSpan>[
        new TextSpan(
            text: '\u2160. Display des Bangles\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
            '1.)	Was zeigt der Bangle an?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Der Bangle zeigt in der Mitte des Displays die Uhrzeit an. '
                'Darunter ist das Datum abzulesen. Die drei Kreise oberhalb '
                'der Uhrzeit zeigen den Akkustand, die gelaufenen Schritte und '
                'die aktiven Minuten an. Der gelbe Kreis oben links zeigt den '
                'Akkustand an. Während der Bangle geladen wird, erscheint anstelle '
                'des Batteriesymbols ein Ladesteckersymbol und der Akkustand steigt an. '
                'Der blaue Kreis, welcher sich oben mittig befindet, zeigt die gelaufenen '
                'Schritte an. Bei einer Schrittzahl von über 10.000 werden die weiteren '
                'Schritte gekürzt angezeigt: z.B. 10.300 Schritte ist gleich 10,3 k. '
                'Der rote Kreis oben rechts zeigt die Aktivität in Minuten an. Die genaue '
                'Aufschlüsselung der aktiven Minuten nach Intensitäten wird in der App '
                'graphisch dargestellt. Wählen Sie in der App links im Menü „Grafiken“ aus, '
                'um sich diese anzusehen.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '2.)	Ich bin gerade ein paar Schritte gegangen, aber die Schrittzahl verändert sich nicht. Woran liegt das?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Der Bangle zeichnet Schritte erst auf, nachdem ein paar Schritte direkt nacheinander erfolgt sind. '
                'Kurze Strecken von 3 - 4 Schritten bleiben somit unaufgezeichnet um keine willkürlichen Bewegungen '
                'als Schritte abzubilden. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '3.)	Wie erkenne ich, ob die Aufnahme gestartet ist? \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Sobald die Aufnahme korrekt gestartet ist, werden zwischen '
                'der Uhrzeit und dem Datum sich verändernde Zahlenkombinationen '
                'angezeigt, die lediglich aussagen, dass die Aufnahme funktioniert.  \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '4.)	Wie erkenne ich, ob der Upload der Daten funktioniert? \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Der Upload der Daten beginnt damit, dass in der App der Button „Ladezyklus“ '
                'angeklickt und eine Startzeit für den nächsten Tag ausgewählt wird. '
                'Beim Upload der Dateien werden die Punkte zwischen der Uhrzeit türkis angezeigt, '
                'so können Sie sicherstellen, dass eine Bluetooth-Verbindung hergestellt wurde und '
                'Daten übertragen werden. Während des Uploads ist das Display des Bangles inaktiv und '
                'schwarz (es schaltet sich auch nicht über die Knöpfe an.) Dies hängt damit zusammen, '
                'dass der Bangle mit dem Upload beschäftigt ist und der Bangle dann nicht genutzt werden kann.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '5.)	Was bedeutet ein schwarzer Bildschirm?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Ein schwarzer Bildschirm kann bedeuten, dass der Akku leer ist oder dass der Upload der Daten läuft.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '6.)	Welche Funktionen haben die Knöpfe?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Mit dem oberen und unteren Knopf schalten Sie das Display an und aus. Der mittlere Knopf hat keine Funktion.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '\u2161. Tragen des Bangles: \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
            '1.)	Wie ist der Bangle zu tragen?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text: 'Der Bangle sollte am nicht-dominanten Handgelenk, für die Zeit direkt nach dem Aufstehen bis zum Zubettgehen getragen werden. '
                'Schließen Sie abends dann sowohl das Smartphone/Tablet, als auch den Bangle zum Laden an den Strom an. '
                'Lassen Sie die Geräte über Nacht dicht beieinander liegen. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '2.)	Ist der Bangle wasserfest?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text: 'Der Bangle ist bis zu 10 Metern Wassertiefe wasserfest, was bedeutet, '
                'dass Sie den Bangle auch beim Duschen, Abwaschen oder Schwimmen gehen tragen können. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '\u2162. Laden des Bangles\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text: '1.)	Worauf muss ich beim Laden des Bangles achten?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Achten Sie beim Laden darauf, dass das Ladekabel von der ‚Knopfseite‘ eingesteckt wird, '
                'da nur dann der Bangle korrekt auflädt. Legen Sie den Bangle zum Laden am besten zurück in '
                'die Verpackung, damit das Ladekabel und ihr Bangle stabilisiert werden. Wir empfehlen, das '
                'Laden und den Upload am Ende des Tages gleichzeitig durchzuführen. Nur wenn Sie das Smartphone '
                'in direkter Nähe zu (im besten Fall neben) dem Bangle platzieren, kann eine einwandfreie Datenübertragung gewährleistet werden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '2.)	Wie erkenne ich, dass der Bangle richtig lädt?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Wenn das Ladegerät korrekt angeschlossen ist, '
                'dann verändert sich der Ladestand stetig und das'
                ' Symbol in dem gelben Kreis verändert sich von '
                'einem Blitz in einen Ladestecker.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '\u2163. App\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
            '1.)	Worauf muss ich beim Nutzen der App achten?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Stellen Sie sicher, dass Bluetooth im Smartphone eingeschaltet ist '
                'und Ihr Bangle sich in unmittelbarer Nähe befindet. Sollte sich '
                'die App nicht korrekt öffnen, schließen Sie diese und öffnen '
                'Sie die App erneut. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '2.)	Wie starte ich den Upload?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Am Ende des Tages öffnen Sie die App „Trac2Move“ und klicken '
                'auf das grüne Feld („Ladezyklus“) oben auf der Startseite '
                'der App. Anschließend können Sie den Beginn der Aufnahme '
                'für den nächsten Tag auswählen und der Upload der Daten startet. '
                'Sie können den Bangle und das Smartphone/Tablet nun zum Aufladen '
                'an den Strom anschließen und nebeneinanderlegen. Bitte wählen '
                'Sie als Startzeit eine Zeit kurz vor Ihrer geplanten Aufstehzeit.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '3.)	Welche Einstellungen gibt es in der App?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'In der App können Sie die Daten übertragen und sehen, wie viele Schritte und aktive Minuten Sie am Tag absolviert haben. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '4.)	Was sind die Tagesziele und wie bearbeite ich sie?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Sie können in den Einstellungen ihre individuellen Schrittziele und aktiven Minuten, '
                'die Sie an einem Tag erreichen möchten, festlegen. Gehen Sie hierzu in die App. '
                'Oben links finden Sie über das Menü (drei Striche) die Option, „Tagesziele bearbeiten“. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '5.)	Was finde ich unter dem Menüpunkt "Grafiken"?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Zu finden sind dort zwei Abbildungen. Die obere Grafik zeigt Ihnen die bisher gegangenen Schritte, '
                'die untere bildet die aktiven Minuten ab. Die Intensität der aktiven Minuten ist unterteilt in '
                'niedrige, mittlere und hohe Intensität. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '6.)	Warum stimmen meine aktiven Minuten des Bangle nicht mit den Minuten in der Grafik überein?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'In der App werden die aktiven Minuten nach Intensität (niedrige, mittlere, hohe) unterteilt abgebildet. '
                'Der Bangle zählt nur die aktiven Minuten in mittlerer und hoher Intensität zusammen und zeigt eine '
                'Gesamtanzahl dieser beiden Werte an, die Minuten in niedriger Intensität werden nicht abgebildet.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
            '7.)	Warum startet meine Aufnahme nicht?\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic)),
        new TextSpan(
            text:
            'Achten Sie beim Einstellen der Aufnahmezeit darauf, dass der Startzeitpunkt in der Zukunft liegt. '
                'Am besten wählen Sie eine Uhrzeit kurz vor dem Aufstehen am nächsten Tag, damit gesichert ist, '
                'dass die Bluetooth-Verbindung zwischen Bangle und Smartphone/Tablet bestehen kann. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
      ],
    ),
  );

  Widget build(BuildContext context) {
    return SafeArea(
      child: new Scaffold(
        appBar: new AppBar(
          title: const AutoSizeText(
            'Häufig gestellte Fragen',
            maxFontSize: 14,
            presetFontSizes: [14, 12, 11, 10, 9, 8],
          ),
          // actions: [
          //   new FlatButton(
          //       onPressed: () {
          //         Navigator.of(context).pop('User Agreed');
          //       },
          //       child: new Text('Zustimmen',
          //           style: Theme.of(context)
          //               .textTheme
          //               .subhead
          //               .copyWith(color: Colors.white))),
          // ],
        ),
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(
                  future: isbctGroup(),
                  builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                    if (snapshot.hasData) {
                      if (snapshot.data == true) {
                        return pdfTextBCT;
                      } else {
                        return pdfTextNonBCT;
                      }
                    } else
                      return Container();
                  }),
            ),
          ],
        )),
      ),
    );
  }

  Future<bool> isbctGroup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> participantAsList = prefs.getStringList("participant");
    Participant p = fromStringList(participantAsList);

    return p.bctGroup;
  }
}
