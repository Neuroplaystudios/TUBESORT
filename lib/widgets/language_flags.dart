String getFlagForLanguage(String lang) {
  switch (lang) {
    case 'English':
      return '🇬🇧';
    case 'Español':
      return '🇪🇸';
    case 'Français':
      return '🇫🇷';
    case 'Русский':
      return '🇷🇺';
    case '中文':
      return '🇨🇳';
    default:
      return '🏳️';
  }
}
