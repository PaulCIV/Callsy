import { LegalPage, Section } from "./LegalPage";

export default function Terms() {
  return (
    <LegalPage title="Terms and Conditions" updated="July 18, 2026">
      <Section title="Agreement">
        <p>These terms govern access to and use of Callsy’s missed-call recovery, messaging, automation, and business communication services. By creating an account or using Callsy, a business agrees to these terms.</p>
      </Section>

      <Section title="Service description">
        <p>Callsy helps participating businesses capture missed calls, request permission to continue by text, exchange service-related messages, identify potential customer needs, and coordinate human follow-up. Callsy does not guarantee that a lead will reply, book, purchase, or receive a message without delay.</p>
      </Section>

      <Section title="Business responsibilities">
        <p>Businesses must provide accurate account information, protect account credentials, use Callsy only for lawful purposes, honor customer choices, and configure messages that accurately identify the sending business. Businesses may not use Callsy to send deceptive, unlawful, unsolicited, or prohibited content.</p>
      </Section>

      <Section title="SMS program terms">
        <p>When a caller affirmatively elects to receive a text, the applicable business may send customer-care messages relating to that call and the resulting service request. Message frequency varies. Message and data rates may apply. Consent to receive text messages is not a condition of purchasing goods or services.</p>
        <p>Reply STOP to cancel. Reply HELP for help. Carriers are not liable for delayed or undelivered messages. A customer who opts out may still contact the business by telephone or another available channel.</p>
      </Section>

      <Section title="Automated assistance">
        <p>Callsy may use automated systems to generate or classify communications. Automated output may be incomplete or incorrect. Businesses remain responsible for reviewing important communications, confirming appointments, handling emergencies, and providing their services. Callsy is not an emergency service.</p>
      </Section>

      <Section title="Availability and third-party services">
        <p>The service relies on telecommunications, hosting, and artificial-intelligence providers. Availability may be interrupted by maintenance, carrier filtering, network failures, regulatory requirements, or events outside Callsy’s control.</p>
      </Section>

      <Section title="Acceptable use">
        <p>Users may not send spam, impersonate another party, evade opt-outs, transmit illegal or harmful material, interfere with the service, probe for vulnerabilities without authorization, or use Callsy in a manner that violates telecommunications or privacy requirements.</p>
      </Section>

      <Section title="Disclaimers and limitation">
        <p>Callsy is provided on an “as available” basis to the extent permitted by law. Callsy does not provide legal advice and does not warrant that a particular configuration satisfies every business’s legal obligations. To the extent permitted by law, Callsy is not responsible for indirect, incidental, special, consequential, or lost-profit damages arising from use of the service.</p>
      </Section>

      <Section title="Changes and contact">
        <p>We may update these terms as the service evolves. Business account holders may direct questions through their established Callsy support channel. Continued use after an update constitutes acceptance where permitted by law.</p>
      </Section>
    </LegalPage>
  );
}
