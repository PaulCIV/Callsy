// src/utils/messageTemplates.ts

import {
    FirstResponseStyle,
    GenerateInitialMessageInput,
    MessageTone
  } from "../services/aiMessage.service";
  
  function clean(value: unknown): string {
    return String(value ?? "").replace(/\s+/g, " ").trim();
  }
  
  export function buildNumberedMenu(options: string[]): string {
    return options
      .map((option, index) => `${index + 1}. ${clean(option)}`)
      .filter(Boolean)
      .join("\n");
  }
  
  export function getDefaultMenuOptions(
    businessType?: string,
    provided?: string[]
  ): string[] {
    const cleanedProvided = Array.isArray(provided)
      ? provided.map(clean).filter(Boolean)
      : [];
  
    if (cleanedProvided.length > 0) {
      return cleanedProvided.slice(0, 4);
    }
  
    const type = clean(businessType).toLowerCase();
  
    if (type.includes("auto")) {
      return [
        "Schedule service",
        "Ask about pricing",
        "Repair question",
        "Something else"
      ];
    }
  
    if (
      type.includes("dental") ||
      type.includes("dentist") ||
      type.includes("doctor") ||
      type.includes("clinic") ||
      type.includes("medical")
    ) {
      return [
        "Book an appointment",
        "Ask about availability",
        "Insurance or pricing",
        "Something else"
      ];
    }
  
    if (
      type.includes("plumb") ||
      type.includes("electric") ||
      type.includes("hvac") ||
      type.includes("roof") ||
      type.includes("contract")
    ) {
      return [
        "Need service",
        "Ask about pricing",
        "Urgent issue",
        "Something else"
      ];
    }
  
    if (
      type.includes("salon") ||
      type.includes("spa") ||
      type.includes("barber") ||
      type.includes("beauty")
    ) {
      return [
        "Book an appointment",
        "Ask about pricing",
        "Ask about services",
        "Something else"
      ];
    }
  
    if (
      type.includes("restaurant") ||
      type.includes("cafe") ||
      type.includes("food")
    ) {
      return [
        "Place an order",
        "Ask about hours",
        "Ask about menu",
        "Something else"
      ];
    }
  
    return [
      "Book an appointment",
      "Ask about pricing",
      "General question",
      "Something else"
    ];
  }
  
  export function buildFallbackMessage(
    input: Pick<
      GenerateInitialMessageInput,
      | "businessName"
      | "businessType"
      | "style"
      | "bookingLink"
      | "menuOptions"
      | "tone"
    >
  ): string {
    const businessName = clean(input.businessName) || "our team";
    const businessType = clean(input.businessType).toLowerCase();
    const style: FirstResponseStyle = input.style ?? "conversational";
    const tone: MessageTone = input.tone ?? "friendly";
    const bookingLink = clean(input.bookingLink);
  
    if (style === "menu") {
      const options = getDefaultMenuOptions(input.businessType, input.menuOptions);
      const intro =
        tone === "professional"
          ? `Hi — this is ${businessName}. Sorry we missed your call. How can we help today?`
          : `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;
  
      return `${intro}\n\n${buildNumberedMenu(options)}`;
    }
  
    if (style === "appointment") {
      let message =
        tone === "direct"
          ? `Hi — this is ${businessName}. Were you trying to book an appointment?`
          : `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to book an appointment?`;
  
      if (bookingLink) {
        message += ` You can also book here: ${bookingLink}`;
      }
  
      return message.trim();
    }
  
    if (businessType.includes("auto")) {
      if (tone === "direct") {
        return `Hi — this is ${businessName}. Were you calling about a repair, service, or pricing?`;
      }
      return `Hi — this is ${businessName}. Sorry we missed your call. Were you calling about a repair, service, or pricing?`;
    }
  
    if (
      businessType.includes("plumb") ||
      businessType.includes("electric") ||
      businessType.includes("hvac")
    ) {
      return `Hi — this is ${businessName}. Sorry we missed your call. What can we help with today?`;
    }
  
    if (
      businessType.includes("salon") ||
      businessType.includes("spa") ||
      businessType.includes("barber")
    ) {
      return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment?`;
    }
  
    if (
      businessType.includes("dental") ||
      businessType.includes("doctor") ||
      businessType.includes("clinic")
    ) {
      return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment or ask a question?`;
    }
  
    if (tone === "professional") {
      return `Hi — this is ${businessName}. Sorry we missed your call. How can we help you today?`;
    }
  
    if (tone === "direct") {
      return `Hi — this is ${businessName}. What can we help with?`;
    }
  
    if (tone === "casual") {
      return `Hi — this is ${businessName}. Sorry we missed your call. What were you calling about?`;
    }
  
    return `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;
  }
  
  export function applyTemplateVariables(
    template: string,
    data: {
      business?: string;
      caller?: string;
      link?: string;
    }
  ): string {
    let msg = clean(template);
  
    msg = msg.split("{{business}}").join(clean(data.business));
    msg = msg.split("{{caller}}").join(clean(data.caller));
    msg = msg.split("{{link}}").join(clean(data.link));
  
    return msg.trim();
  }
  
  export function finalizeMessage(
    baseMessage: string,
    style?: FirstResponseStyle,
    menuOptions?: string[],
    businessType?: string
  ): string {
    let message = clean(baseMessage);
  
    if ((style ?? "conversational") === "menu") {
      const hasMenuAlready = /\b1\.\s/.test(message);
      if (!hasMenuAlready) {
        const options = getDefaultMenuOptions(businessType, menuOptions);
        message = `${message}\n\n${buildNumberedMenu(options)}`;
      }
    }
  
    return message.trim();
  }