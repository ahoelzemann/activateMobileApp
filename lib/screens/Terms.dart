import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Terms extends StatefulWidget {
  @override
  State<Terms> createState() => _TermsState();
}

class _TermsState extends State<Terms> {
  bool agreedData = false;
  bool agreedSickness = false;
  var pdfText = new RichText(
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
            text: 'Liebe Nutzerin, lieber Nutzer,\n\n'
                'Sie nehmen an der wissenschaftlichen Studie „ActiVAtE_Prevention“ '
                'der Universität Vechta teil. Durch diese Studie sollen Fragestellungen '
                'zum Bewegungsverhalten beantwortet und eine umfassende Datenbasis geschaffen werden. '
                'Körperliche Aktivität (Bewegung) kann das Risiko, an Diabetes (Zuckerkrankheit) '
                'zu erkranken, reduzieren und zu einer Reduzierung des Langzeitblutzuckerwertes bei '
                'Personen mit Diabetes oder Prädiabetes führen. Um den Einfluss der Faktoren, die auf '
                'die körperliche Aktivität wirken, besser zu verstehen bedarf es objektiv erhobener und '
                'verlässlicher Bewegungsdaten. Ziel des Forschungsprojektes ist es deshalb, Daten zum '
                'Bewegungsverhalten zu erheben. Alle Teilnehmenden erhalten entweder zu Beginn oder am Ende des '
                ' Untersuchungszeitraumes ein Fitnessarmband, mithilfe dessen und eines Smartphones das Bewegungs- und '
                'Aktivitätsverhalten objektiv beobachtet werden kann. Weitere Gesundheitsdaten werden hiermit durch '
                'die Wissenschaftler nicht erfasst. Zudemnehmen Sie an einer zusätzlichen technikgestützten Maßnahme '
                'zur Förderung des Bewegungsverhaltens teil (Fitnessarmband und Smartphone-App).\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Die Studie wird an der Universität Vechta durchgeführt und von Prof. Dr. Andrea Teti, '
                'Universität Vechta, Prof. Dr. Iris Pahmeier, Universität Vechta, Dr. med. Silke Otto-Hagemann, '
                'Diabetologische Schwerpunktpraxis, und Prof. Dr. med. Dr. phil. Dietrich Doll, St. Marienhospital Vechta, '
                'geleitet. Die Studie findet im Rahmen eines Forschungsprojekts statt, das aus Mitteln des Niedersächsischen '
                'Vorab (Förderkennzeichen: VW-ZN-3426) gefördert wird. Das Niedersächsische Vorab ist ein Förderangebot der '
                'Volkswagenstiftung, mit dem auf Vorschlag der Niedersächsischen Landesregierung Forschungsvorhaben an '
                'Hochschulen und wissenschaftlichen Einrichtungen in Niedersachsen unterstützt werden. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Im Rahmen der Studie sollen Daten über Ihr Bewegungsverhalten technikgestützt erfasst und ausgewertet werden. '
                'Wir möchten über 9 Monate die ermittelten Daten für unsere Studie verwenden und auswerten. Dabei handelt es sich '
                'um folgende Daten: soziodemographische (z. B. Alter, Herkunft, …), sozioökonomische (z. B. Schulabschluss, Ausbildung) '
                'sowie psychosoziale Daten (z. B. Motivation), Daten zu Ihrem Gesundheitsstatus (z. B. Vorerkrankungen) sowie Bewegungsverhalten '
                'und Diabetesparameter. Dieser Zeitraum unterteilt sich in 6 Monate zu Beginn der Studie, in denen Sie ein Fitnessarmband '
                'tragen sowie im Anschluss 3 Monate ohne dieses Armband. Der letzte Termin im Rahmen der Studie liegt 9 Monate nach der '
                'Einbindung in die Studie, es handelt sich dabei um das letzte Ausfüllen eines Fragebogens (siehe unten). \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Die für die Studie relevanten Diabetesparameter werden von medizinischem Fachpersonal erfasst '
                'und ausgewertet. Dabei handelt es sich um folgende Daten: Anamnese und Diabetesparameter (HbA1c-Wert, '
                'BMI, Blutdruck, ggf. weitere diabetesbezogene Parameter). \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Sollten im Zuge der o.g. Untersuchungen bedenkliche Gesundheitswerte auftreten, werden Sie sowie ggf. die in der Studie '
                'involvierten Fachärzte über diese informiert, sofern Sie diesem Vorgehen nicht ausdrücklich widersprechen (siehe unten). \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Sie werden gebeten, zusätzlich zum üblichen medizinischen Vorgehen insgesamt vier Online-Fragebögen auszufüllen. '
                'Die genannten studienbedingten Maßnahmen erfordern einen zusätzlichen Zeitaufwand von etwa 45-60 Minuten pro '
                'Befragung. Für die Teilnahme an der gesundheitsförderlichen Maßnahme ausgewählt werden, erhalten Sie hierzu einmalig '
                'eine kurze Einführung in die dazugehörige Technik, die in etwa 30 Minuten dauern wird. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Die Teilnahme an dieser Studie ist freiwillig. Sie werden nur dann einbezogen, wenn Sie dazu schriftlich Ihre '
                'Einwilligung erklären. Sofern Sie nicht an der Studie teilnehmen oder später aus ihr ausscheiden möchten, '
                'entstehen Ihnen dadurch keine Nachteile. Sie können jederzeit, auch ohne Angabe von Gründen, Ihre Einwilligung '
                'mündlich oder schriftlich widerrufen. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Die Studie wurde der Ethikkommission bei der Ärztekammer Niedersachsen zur berufsrechtlichen und berufsethischen '
                'Beratung der an dem Forschungsvorhaben beteiligten Ärzte vorgelegt. Sie hatte keine grundsätzlichen Bedenken '
                'gegen die Durchführung der Studie; Empfehlungen und Hinweise der Ethikkommission wurden berücksichtigt.  \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Mögliche Risiken, Beschwerden und Begleiterscheinungen \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Da im Rahmen unserer Studie nur Daten erhoben werden, sind mit der Teilnahme keine medizinischen Risiken verbunden. '
                'Sofern Sie für die Teilnahme an der gesundheitsförderlichen Maßnahme ausgewählt werden, die ausschließlich eine Veränderung '
                'des Bewegungsverhaltens bewirken kann, könnte als Folge der erhöhten Bewegung eine Unterzuckerung eintreten. In der Einführung '
                'der Maßnahme wird auf dieses Risiko hingewiesen und werden Maßnahmen vorgestellt, wie das Risiko reduziert werden kann. '
                'Patientinnen und Patienten, für die ein besonders hohes Risiko besteht, werden von der Teilnahme an dieser Studie ausgeschlossen.  \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Möglicher Nutzen aus Ihrer Teilnahme an der Studie \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Sie werden durch Ihre Teilnahme an dieser Studie eher einen geringfügigen medizinischen Nutzen für Ihre '
                'Gesundheit haben. Die Teilnahme an der Studie kann Sie für das Thema Bewegung sensibilisieren und sich '
                'dadurch auf Ihr Bewegungsverhalten auswirken. Bewegung kann sich positiv auf Ihre Gesundheit auswirken, in dem ggf. '
                '(Folge-)Erkrankungen, die durch Bewegungsmangel entstehen, vermieden werden. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Ansprechpartner für Fragen zur Studie\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Wenn Sie Fragen zu dieser Studie haben, wenden Sie sich bitte an:\n\n'
                'Projektbüro ActiVAtE_Prävention\n'
                'FON +49. (0) 4441.15 733\n'
                'activate-prevention@uni-vechta.de\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Datenschutz \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                '•	Rechtsgrundlage für die Datenverarbeitung ist Ihre freiwillige Einwilligung (Art. 6 Abs. 1 Buchst. a) sowie Art. 9 DSGVO). \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '• Der Verantwortliche für die Datenverarbeitung ist: \n'
                'Prof. Dr. Andrea Teti \n'
                'Universität Vechta \n'
                'Institut für Gerontologie \n'
                'Driverstraße 23 \n'
                '49377 Vechta \n'
                'FON +49. (0) 4441.15 791 \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: '• Datenschutzbeauftrage der Universität Vechta ist: \n'
                'Frau Anja Schöndube \n'
                'Universität Vechta \n'
                'Driverstraße 22 \n'
                '49377 Vechta \n'
                'FON +49. (0) 4441.15 272 \n'
                'FAX  +49. (0) 4441.15 451\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Wer hat Zugriff auf die Daten und verarbeitet diese? \n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Zugriff auf die personenbezogenen Daten haben die Projektverantwortlichen '
                'und Mitarbeiter des Projekts an der Universität Vechta, sowie das '
                'medizinische Personal der Diabetologischen Schwerpunktpraxis. Diese Personen sind zur '
                'vertraulichen Behandlung der Daten verpflichtet. Alle weiteren Verarbeitungen zu '
                'wissenschaftlichen Zwecken werden durch die Projektmitarbeitenden durchgeführt; '
                'diese verarbeiten nur pseudonymisierte Daten. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Pseudonymisierung und Anonymisierung\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Ihre Daten werden pseudonymisiert verarbeitet. Das bedeutet, dass Ihrer Person zu Beginn '
                'der Studie ein Code („Pseudonym“) aus Nummern und/oder Zahlen zugeordnet wird. Ihre '
                'direkten personenbezogenen Informationen (z.B. Ihr Name und das Geburtsdatum) werden '
                'schon während der Datenerhebung durch das Pseudonym ersetzt. Die Zuordnung zwischen '
                'Namen und Pseudonym wird auf einer Pseudonymisierungsliste festgehalten. Daten können '
                'einer konkreten Person nur noch mit Hilfe dieser Liste zugeordnet werden. Diese Liste '
                'wird gesondert, d. h. getrennt von allen übrigen Daten, aufbewahrt und unterliegt dort '
                'technischen und organisatorischen Maßnahmen, die gewährleisten, dass unbefugte Personen '
                'nicht auf diese Liste Zugriff bekommen. '
                'Eine Entschlüsselung erfolgt nur in folgenden Situationen: \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '(1)	Wenn Sie Ihre Datenschutzrechte (s. unten) wahrnehmen wollen und es dazu nötig ist, Ihre Daten eindeutig zu identifizieren.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                '(2)	Kontaktaufnahmen, die dem wissenschaftlichen Zweck des Forschungsprojekts dienen, sofern hierzu eine gesonderte Einwilligung von Ihnen vorliegt.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Ihre Daten werden so früh wie möglich im Projektverlauf anonymisiert; dies geschieht u. a. '
                'durch Entfernen der Pseudonyme aus den Daten und durch Vernichten der zuvor beschriebenen Codierungsliste. '
                'Wenn Daten anonymisiert sind, bedeutet dies, dass es keine Möglichkeit mehr gibt, sie einer bestimmten Person zuzuordnen.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Was für Daten werden verarbeitet, wie werden diese Daten verarbeitet?\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Verarbeitet werden die in der Teilnahmeinformation beschriebenen Personendaten, '
                'Bewegungsdaten und Gesundheitsdaten (letztere fallen unter die besonderen '
                'Kategorien personenbezogener Daten nach Art. 9 Abs. 1 DSGVO). '
                'Die Bewegungs- und Gesundheitsdaten werden zusammengeführt und mit '
                'wissenschaftlichen Methoden statistisch ausgewertet und interpretiert. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Erhebung, Speicherung und Entfernung personenbezogener Daten\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Die Daten werden durch Sie sowie technikgestützt und durch das von den '
                'Projektverantwortlichen beauftragte medizinische Personal der Diabetologischen '
                'Schwerpunktpraxis erhoben. Sie werden anschließend in pseudonymisierter Form '
                '(s. oben) an die Projektmitarbeitenden an der Universität Vechta zum Zweck der '
                'wissenschaftlichen Verarbeitung übermittelt. Die Daten werden in gesonderten '
                'Bereichen des IT-Systems der Universität Vechta gespeichert und durch Methoden '
                'der IT-Sicherheit (z. B. Zugriffsregelung, Verschlüsselung, Sicherheitskopien) vor '
                'unberechtigter Einsicht oder Verlust geschützt. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Der Personenbezug in Ihren Daten wird durch die Anonymisierung entfernt; '
                'dabei werden auch Ihre gesondert aufbewahrten Personendaten gelöscht. '
                'Dies erfolgt spätestens zum 31.10.2023.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Aufbewahrung und Veröffentlichung von Daten, Weitergabe von Daten an Dritte\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Die in dieser Studie gesammelten Daten werden nach Projektende – ausschließlich in '
                'anonymisierter und zusammengefasster Form – langfristig (für mind. 10 Jahre) '
                'aufbewahrt. Dazu werden sie einem Forschungsdatenzentrum, z. B. im Rahmen der '
                'Nationalen Forschungsdateninfrastruktur (nfdi), übergeben. Über dieses Datenzentrum'
                ' werden sie außerdem anderen Forschenden zu wissenschaftlichen Zwecken, die der '
                'Beantwortung von ähnlichen Fragstellungen der Gesundheitsforschung dienen wie diese Studie, '
                'zur Verfügung gestellt. Die Daten und Ergebnisse dieser Studie werden – ebenfalls in '
                'anonymisierter Form – in wissenschaftlichen Publikationen (z. B. in Artikeln in Fachzeitschriften) beschrieben. \n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Darüber hinaus findet keine Weitergabe von Daten an Dritte statt, insbesondere nicht in andere Länder '
                'innerhalb oder außerhalb des EU-Binnenraumes.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Sind mit der Datenverarbeitung Risiken verbunden?\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Bei jeder Erhebung, Speicherung, Nutzung und Übermittlung von Daten bestehen Vertraulichkeitsrisiken '
                '(z. B. die Möglichkeit, die betreffende Person zu identifizieren oder eine Einsichtnahme durch '
                'unberechtigte Dritte). Diese Risiken lassen sich nicht völlig ausschließen und steigen, je mehr '
                'Daten miteinander verknüpft werden können. Der Initiator der Studie versichert Ihnen, alles nach '
                'dem Stand der Technik Mögliche zum Schutz Ihrer Privatsphäre zu tun und Daten nur an Stellen weiterzugeben, '
                'die ein geeignetes Datenschutzkonzept vorweisen können. Medizinische Risiken sind mit der Datenverarbeitung '
                'nicht verbunden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Der Initiator der Studie wird sich bemühen, ein entsprechendes Datenschutzniveau zu gewährleisten.'
                'Beachten Sie: Die Daten werden nur in pseudonymisierter oder anonymisierter Form weitergegeben. '
                'Gemeinsam mit der Datenschutzbeauftragten und dem Datenmanager der Universität Vechta wurde ein '
                'Datenschutzkonzept für diese Studie entwickelt. Dieses kann bei der Datenschutzbeauftragten der '
                'Universität Vechta (s. oben) eingesehen werden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Kann ich meine Einwilligung widerrufen?\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Sie können Ihre jeweilige Einwilligung jederzeit ohne Angabe von Gründen schriftlich oder mündlich ganz oder teilweise widerrufen, '
                'ohne dass Ihnen daraus ein Nachteil entsteht. Wenn Sie Ihre Einwilligung widerrufen, werden – je nach Art des Widerrufs – keine '
                'weiteren Daten mehr erhoben und/oder verarbeitet. Die bis zum Widerruf erfolgte Datenverarbeitung bleibt jedoch rechtmäßig. '
                'Sie können auch die Löschung Ihrer Daten verlangen (s. nächster Punkt).\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text: 'Welche Rechte habe ich bezogen auf den Datenschutz?\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                'Sie haben jederzeit das Recht, die Löschung Ihrer personenbezogenen Daten zu verlangen; dann werden die betreffenden Daten '
                'sofort und so schnell wie möglich gezielt aus allen Aufzeichnungen entfernt und die Löschung der Daten dokumentiert. '
                'Sie haben außerdem das Recht, vom Verantwortlichen Auskunft über die von Ihnen gespeicherten personenbezogenen Daten '
                '(einschließlich der kostenlosen Überlassung einer Kopie der Daten) zu verlangen. Ebenfalls können Sie die Berichtigung '
                'unzutreffender Daten sowie gegebenenfalls eine Übertragung der von Ihnen zur Verfügung gestellten Daten und die Einschränkung '
                'ihrer Verarbeitung verlangen.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Diese Rechte haben Sie bis zu dem Zeitpunkt, ab dem die Daten anonymisiert sind, d. h. nicht mehr einer bestimmten Person '
                'zugeordnet werden können. Bei Anliegen zur Datenverarbeitung und zur Einhaltung der datenschutzrechtlichen Anforderungen '
                'können Sie sich an die Datenschutzbeauftragte der Universität Vechta (s. oben) wenden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'Sie haben ein Beschwerderecht bei jeder Aufsichtsbehörde für den Datenschutz. Eine Liste der Aufsichtsbehörden in Deutschland finden Sie unter\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
        new TextSpan(
            text:
                'https://www.bfdi.bund.de/DE/Infothek/Anschriften_Links/anschriften_links-node.html\n\n',
            style:
                new TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launch(
                  'https://www.bfdi.bund.de/DE/Infothek/Anschriften_Links/anschriften_links-node.html')),
        new TextSpan(
            text: 'Zusammenfassung\n\n',
            style: new TextStyle(fontWeight: FontWeight.bold)),
        new TextSpan(
            text:
                '1.	Ich bin über Wesen, Bedeutung und Tragweite der Studie sowie die sich für mich daraus ergebenden Anforderungen aufgeklärt worden. Ich habe darüber hinaus den oben stehenden Text der Patientenaufklärung, einschließlich der Angaben zum Datenschutz, und dieser Einwilligungserklärung gelesen.\n\n'
                '2.	Ich hatte ausreichend Zeit, Fragen zu stellen und mich zu entscheiden. Aufgetretene Fragen wurden mir vom Studienpersonal beantwortet.\n\n'
                '3.	Ich weiß, dass ich meine freiwillige Mitwirkung jederzeit beenden kann, ohne dass mir daraus Nachteile entstehen.\n\n'
                '4.	Ich erkläre mich bereit, an der Studie teilzunehmen.\n\n'
                '5.	Ich willige ein, dass im Rahmen des Forschungsprojekts ActiVAte_Prävention personenbezogene Daten über mich, wie in der Informationsschrift beschrieben, zu wissenschaftlichen Zwecken im Feld der Gesundheitsforschung erhoben und technikgestützt aufgezeichnet werden.\n\n'
                '6.	Soweit erforderlich, dürfen die erhobenen Daten pseudonymisiert (verschlüsselt) weitergegeben werden an die im Forschungsprojekt ActiVAte_Prävention mitarbeitenden Forschenden.\n\n'
                '7.	Außerdem willige ich ein, dass autorisierte und zur Verschwiegenheit verpflichtete Beauftragte des Initiators der Studie Einsicht in die Behandlungsunterlagen bei meinem behandelnden Facharzt für Diabetologie nehmen, soweit dies zur Überprüfung der Datenübertragung erforderlich ist. Für diese Maßnahme entbinde ich die jeweiligen Ärzte von der Schweigepflicht.\n\n'
                '8.	Ich weiß, dass ich diese Einwilligung jederzeit widerrufen kann. Im Falle des Widerrufs werden keine weiteren Daten mehr erhoben. Ich kann in diesem Fall die Löschung der Daten verlangen. Die bis zum Widerruf erfolgte Datenverarbeitung bleibt jedoch rechtmäßig.\n\n'
                '9.	Ich willige ein, dass die Ergebnisse und anonymisierten Daten dieser Studie in wissenschaftlichen Veröffentlichungen (z. B. in Artikeln in einer Fachzeitschrift) beschrieben werden.\n\n',
            style: new TextStyle(fontWeight: FontWeight.normal)),
      ],
    ),
  );

  Widget build(BuildContext context) {
    return SafeArea(
      child: new Scaffold(
        appBar: new AppBar(
          title: const AutoSizeText(
            'Einwilligungserklärung',
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
              child: pdfText,
            ),
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                  "Ich willige ein, dass die Daten der Studie ausschließlich in anonymisierter Form anderen Forschenden außerhalb des Projekts zu wissenschaftlichen Zwecken mit ähnlichen Fragestellungen zur Verfügung gestellt werden."),
              subtitle: new RichText(
                  textAlign: TextAlign.left,
                  text: new TextSpan(
                      text: "*optional",
                      // Note: Styles for TextSpans must be explicitly defined.
                      // Child text spans will inherit styles from parent
                      style: new TextStyle(
                        color: Colors.red,
                      ))),
              value: agreedData,
              onChanged: (bool value) {
                setState(
                  () {
                    this.agreedData = value;
                  },
                );
              },
            ),
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              subtitle: new RichText(
                textAlign: TextAlign.left,
                text: new TextSpan(
                  text: "*optional",
                  // Note: Styles for TextSpans must be explicitly defined.
                  // Child text spans will inherit styles from parent
                  style: new TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
              title: Text(
                  "Über bedenkliche Gesundheitsparameter, die im Zuge der Untersuchungen bei mir festgestellt werden, möchte ich nicht informiert werden."),
              value: agreedSickness,
              onChanged: (bool value) {
                setState(
                  () {
                    this.agreedSickness = value;
                  },
                );
              },
            ),
            _getSaveButton()
          ],
        )),
      ),
    );
  }

  Widget _getSaveButton() {
    return Padding(
      padding: EdgeInsets.only(left: 25.0, right: 25.0, top: 45.0),
      child: new Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 10.0),
              child: Container(
                  child: new RaisedButton(
                child: new Text("Zustimmen"),
                textColor: Colors.white,
                color: Colors.green,
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  if (agreedData && agreedSickness) {
                    prefs.setString("agreedOnTerms", "both");
                  }
                  else if (!agreedData && agreedSickness) {
                    prefs.setString("agreedOnTerms", "sick");
                  }
                  else if (agreedData && !agreedSickness) {
                    prefs.setString("agreedOnTerms", "data");
                  }
                  else prefs.setString("agreedOnTerms", "none");

                  Navigator.pop(context, true);
                },
                shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(20.0)),
              )),
            ),
            flex: 2,
          ),
        ],
      ),
    );
  }
}
