import 'package:flutter/material.dart';
import 'package:squall/core/settings/settings_provider.dart';
import 'package:provider/provider.dart';

class Translations {
  final String locale;
  Translations(this.locale);

  static Translations of(BuildContext context) {
    final l = context.select<SettingsProvider, Locale>((s) => s.locale);
    return Translations(l.languageCode);
  }

  String call(String key) {
    if (locale != 'ru') return key;
    return _ru[key] ?? key;
  }

  static final Map<String, String> _ru = {
    'Home': 'Главная', 'Servers': 'Серверы', 'Friends': 'Друзья',
    'Messages': 'Сообщения', 'Parties': 'Пати', 'Profile': 'Профиль',
    'Settings': 'Настройки', 'Voice Channel': 'Голосовой канал',
    'Join to talk with your squad': 'Присоединяйтесь к разговору',
    'Join Voice': 'Войти', 'In the call': 'Вы в звонке',
    'Waiting for others to join...': 'Ожидание участников...',
    'Sign Out': 'Выйти', 'Voice & Audio': 'Голос и звук',
    'Appearance': 'Внешний вид', 'Notifications': 'Уведомления',
    'Account': 'Аккаунт', 'Language': 'Язык',
    'Reduced Effects': 'Упрощённые эффекты',
    'Show Online Only': 'Только онлайн',
    'Sound on Notification': 'Звук уведомлений',
    'Master Volume': 'Громкость', 'Mic Sensitivity': 'Чувствительность микрофона',
    'Push to Talk': 'Push to Talk',
    'Voice Activity Detection': 'Определение голоса',
    'Edit Profile': 'Редактировать профиль',
    'Display Name': 'Отображаемое имя',
    'Username': 'Имя пользователя', 'Status': 'Статус',
    'Member Since': 'На сайте с', 'Save': 'Сохранить', 'Cancel': 'Отмена',
    'Create': 'Создать', 'No parties found': 'Пати не найдены',
    'Create one or adjust filters': 'Создайте новую или измените фильтры',
    'Filter': 'Фильтр', 'Your Servers': 'Ваши серверы',
    'Welcome to Squall': 'Добро пожаловать в Squall',
    'Use the navigation on the left': 'Используйте навигацию слева',
    'No servers yet': 'Пока нет серверов',
    'All': 'Все', 'Online': 'Онлайн', 'Pending': 'Заявки',
    'Blocked': 'Заблокированы', 'Add Friend': 'Добавить друга',
    'Search': 'Поиск', 'Create Server': 'Создать сервер',
    'Discover': 'Обзор', 'Join with Invite': 'По приглашению',
    'Joined': 'Вошли', 'Leave': 'Выйти', 'Delete': 'Удалить',
    'Copy': 'Копировать', 'Invite': 'Пригласить',
    'Muted': 'Без звука', 'Connected': 'Подключён',
    'Speaking...': 'Говорит...', 'You': 'Вы',
    'Retry': 'Повторить', 'Failed to connect': 'Ошибка подключения',
    'Calls are not configured': 'Звонки не настроены',
    'Live': 'В эфире', 'Connecting...': 'Подключение...',
    'Voice': 'Голос', 'Streaming': 'Стримит',
    'Watch': 'Смотреть', 'Close Stream': 'Закрыть стрим',
    'Set Avatar': 'Установить аватар',
    'Paste from clipboard': 'Из буфера обмена',
    'Enter image URL': 'Ввести URL', 'Remove avatar': 'Удалить аватар',
    'No conversations yet': 'Нет переписок',
    'Start a new DM': 'Начните новый диалог',
    'Start Chat': 'Написать', 'Join': 'Присоединиться',
    'Create Party': 'Создать пати', 'Cancel Party': 'Отменить',
    'Game': 'Игра', 'Players': 'Игроки',
    'Description': 'Описание', 'Mode': 'Режим',
    'Platform': 'Платформа', 'Min Rank': 'Мин. ранг',
    'Any': 'Любой',
  };
}

extension Translate on String {
  String t(BuildContext context) => Translations.of(context).call(this);
}