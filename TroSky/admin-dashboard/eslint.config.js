import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  {
    ignores: [
      'dist',
      'dist-demo',
      'coverage',
      'playwright-report',
      'test-results',
      'public/mockServiceWorker.js',
      'src/api/schema.d.ts',
    ],
  },
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      ...tseslint.configs.recommended,
      jsxA11y.flatConfigs.recommended,
    ],
    languageOptions: {
      ecmaVersion: 2023,
      globals: { ...globals.browser },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_', ignoreRestSiblings: true },
      ],
      '@typescript-eslint/consistent-type-imports': ['error', { fixStyle: 'inline-type-imports' }],
      'no-restricted-syntax': [
        'error',
        {
          selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
          message: 'User-supplied text is never rendered as HTML.',
        },
      ],
      'no-restricted-globals': [
        'error',
        { name: 'localStorage', message: 'Use lib/storage (per-viewer conveniences only).' },
      ],
    },
  },
  {
    // shadcn/ui primitives are vendored as generated; they export variants too.
    files: ['src/components/ui/**/*.{ts,tsx}'],
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  {
    // The chart's <style> holds colours from our own chart configs, never
    // user-supplied text.
    files: ['src/components/ui/chart.tsx'],
    rules: { 'no-restricted-syntax': 'off' },
  },
  {
    files: [
      '**/*.test.{ts,tsx}',
      'src/test/**',
      'src/app/router.tsx',
      'e2e/**',
      '*.config.ts',
      'scripts/**',
    ],
    languageOptions: { globals: { ...globals.node, ...globals.browser } },
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  prettier,
)
