import 'package:navis_mobile/core/config/env.dart';

/// The link that goes out with an invite code.
///
/// It is an **https** link to the API, not the `navis://join?code=…` scheme it
/// used to be. A custom scheme is dead text in most messaging apps: WhatsApp
/// does not linkify it, and on a phone without Navis installed tapping it does
/// nothing at all — the recipient is simply stuck. The API page at `/join`
/// bounces straight into the app when it is installed and otherwise offers the
/// download, which is what the sender expects to happen.
///
/// The code stays in the message body too, so joining by hand always works.
String boatJoinLink(String code) => '${Env.apiUrl}/join?code=$code';

/// The in-app scheme the [boatJoinLink] page redirects to, and what the app
/// itself listens for. Kept next to the link it pairs with.
String boatJoinDeepLink(String code) => 'navis://join?code=$code';
