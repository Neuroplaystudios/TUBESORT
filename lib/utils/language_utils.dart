String getFlagForLanguage(String language) {
  switch (language) {
    case 'English':
      return '🇬🇧'; // Reino Unido
    case 'Español':
      return '🇪🇸'; // España
    case 'Français':
      return '🇫🇷'; // Francia
    case 'Русский':
      return '🇷🇺'; // Rusia
    case '中文':
      return '🇨🇳'; // China
    default:
      return '🏳️'; // Bandera blanca por defecto
  }
}