import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Semantic icon vocabulary for the app.
///
/// Screens should use these names instead of importing [Symbols] directly. This
/// keeps the visual language consistent and lets us change icon families later
/// without rewriting feature code.
abstract final class CivicIcons {
  // Primary navigation.
  static const IconData home = Symbols.home_rounded;
  static const IconData explore = Symbols.explore_rounded;
  static const IconData write = Symbols.edit_square_rounded;
  static const IconData activity = Symbols.history_rounded;
  static const IconData profile = Symbols.account_circle_rounded;
  static const IconData notifications = Symbols.notifications_rounded;

  // Finding a constituent's delegation.
  static const IconData search = Symbols.search_rounded;
  static const IconData address = Symbols.location_on_rounded;
  static const IconData useMyLocation = Symbols.my_location_rounded;
  static const IconData homeAddress = Symbols.home_pin_rounded;
  static const IconData district = Symbols.map_rounded;
  static const IconData state = Symbols.map_search_rounded;
  static const IconData city = Symbols.location_city_rounded;
  static const IconData county = Symbols.landscape_rounded;
  static const IconData matched = Symbols.where_to_vote_rounded;

  // People and institutions.
  static const IconData president = Symbols.account_balance_rounded;
  static const IconData congress = Symbols.groups_rounded;
  static const IconData senate = Symbols.group_rounded;
  static const IconData house = Symbols.domain_rounded;
  static const IconData representative = Symbols.person_rounded;
  static const IconData court = Symbols.balance_rounded;
  static const IconData governor = Symbols.apartment_rounded;
  static const IconData delegation = Symbols.diversity_3_rounded;

  // Message composition and delivery.
  static const IconData topic = Symbols.category_rounded;
  static const IconData subject = Symbols.title_rounded;
  static const IconData message = Symbols.chat_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData review = Symbols.fact_check_rounded;
  static const IconData send = Symbols.send_rounded;
  static const IconData delivered = Symbols.mark_email_read_rounded;
  static const IconData receipt = Symbols.receipt_long_rounded;
  static const IconData copy = Symbols.content_copy_rounded;
  static const IconData retry = Symbols.refresh_rounded;

  // Trust and status.
  static const IconData privacy = Symbols.shield_lock_rounded;
  static const IconData secure = Symbols.lock_rounded;
  static const IconData verified = Symbols.verified_user_rounded;
  static const IconData success = Symbols.check_circle_rounded;
  static const IconData warning = Symbols.warning_rounded;
  static const IconData error = Symbols.error_rounded;
  static const IconData info = Symbols.info_rounded;

  // Civic information and external actions.
  static const IconData election = Symbols.how_to_vote_rounded;
  static const IconData ballot = Symbols.ballot_rounded;
  static const IconData legislation = Symbols.gavel_rounded;
  static const IconData calendar = Symbols.calendar_month_rounded;
  static const IconData phone = Symbols.call_rounded;
  static const IconData website = Symbols.language_rounded;
  static const IconData externalLink = Symbols.open_in_new_rounded;
  static const IconData share = Symbols.share_rounded;

  // Directional controls.
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData forward = Symbols.arrow_forward_rounded;
  static const IconData next = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData expand = Symbols.expand_more_rounded;
}
