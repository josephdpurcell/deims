<?php

/**
 * @file
 * Enables modules and site configuration for a DEIMS site installation.
 */

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function deims_form_install_configure_form_alter(&$form, $form_state) {
  // The installer doesn't support 'scope' => 'footer' so load the Chosen JS
  // manually.
  drupal_add_js(drupal_get_path('module', 'chosen') . '/chosen.js',
    array('type' => 'file', 'weight' => JS_DEFAULT)
  );

  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];

  // Add an environment selector.
  // @todo Add a helpful #description to this element.
  $form['site_information']['environment'] = array(
    '#type' => 'select',
    '#title' => t('Environment'),
    '#options' => array(
      'development' => st('Development'),
      'production' => st('Production'),
    ),
    '#default_value' => variable_get('environment', 'development'),
    '#required' => TRUE,
  );

  $form['#submit'][] = 'deims_form_install_configure_form_submit';
}

function deims_form_install_configure_form_submit($form, &$form_state) {
  variable_set('environment', $form_state['values']['environment']);
  module_invoke_all('environment_switch', $form_state['values']['environment'], NULL);
}

/**
 * Implements hook_date_format_types().
 */
function deims_date_format_types() {
  return array(
    'iso_8601' => t('ISO 8601'),
  );
}

/**
 * Implements hook_date_formats().
 */
function deims_date_formats() {
  return array(
    array(
      'type' => 'iso_8601',
      'format' => 'Y-m-d\TH:i:sO',
      'locales' => array(),
    ),
  );
}

/**
 * Implements hook_element_info_alter().
 */
function deims_element_info_alter(&$info) {
  // Merge in some defaults to select or other elements. This makes it so that
  // if a select field is converted to select_or_other, that if #default_value
  // is not in the array of #options, then it will show the 'Other' field
  // pre-filled in the form.
  if (isset($info['select_or_other'])) {
    $info['select_or_other'] += array(
      '#other_unknown_defaults' => 'other',
      '#other_delimiter' => FALSE,
    );
  }
}

/**
 * Implements hook_entity_info().
 */
function deims_entity_info() {
  $info = array();

  // Expose the biblio_contributors_data table as an entity base table so that
  // we can make entity references to biblio authors.
  if (module_exists('biblio')) {
    $info['biblio_contributor'] = array(
      'label' => t('Biblio authors'),
      'base table' => 'biblio_contributor_data',
      'entity keys' => array(
        'id' => 'cid',
        'label' => 'name',
      ),
    );
  }

  return $info;
}

/**
 * Implements hook_preprocess_HOOK().
 *
 * Fix ECK entities to not display a title if they do not have title properies.
 */
function deims_preprocess_entity(&$variables) {
  $entity_type = $variables['elements']['#entity_type'];
  $info = entity_get_info($entity_type);
  if (strpos($info['base table'], 'eck') !== FALSE && empty($info['entity keys']['label'])) {
    $variables['page'] = TRUE;
  }
}

/**
 * Implements hook_field_widget_WIDGET_TYPE_form_alter().
 *
 * Tweak the email widget to use an HTML5 input element.
 */
function deims_field_widget_email_textfield_form_alter(&$element, &$form_state, $context) {
  $element['email']['#type'] = 'emailfield';
}

/**
 * Implements hook_field_widget_WIDGET_TYPE_form_alter().
 *
 * Tweak the number widget to use an HTML5 input element.
 */
function deims_field_widget_number_form_alter(&$element, &$form_state, $context) {
  if ($context['field']['type'] == 'number_integer') {
    $element['value']['#type'] = 'numberfield';
    if (drupal_strlen($context['instance']['settings']['min'])) {
      $element['value']['#min'] = $context['instance']['settings']['min'];
    }
    if (drupal_strlen($context['instance']['settings']['max'])) {
      $element['value']['#max'] = $context['instance']['settings']['max'];
    }
  }
}

/**
 * Implements hook_field_widget_WIDGET_TYPE_form_alter().
 *
 * Make some visiual tweaks to the inline entity form and it's subforms.
 */
function deims_field_widget_inline_entity_form_form_alter(&$element, &$form_state, $context) {
  $info = entity_get_info($element['entities']['#entity_type']);

  // If there is ony one bundle available to use, change the wording in the
  // buttons to be more helpful and reference that bundle only, rather than
  // the entity type.
  if (!empty($element['actions']['bundle']['#value']) && $element['actions']['bundle']['#type'] == 'value') {
    $bundle = drupal_strtolower($info['bundles'][$element['actions']['bundle']['#value']]['label']);
    $bundle_lowercase = drupal_strtolower($bundle);
    if (isset($element['actions']['ief_add']['#value'])) {
      $element['actions']['ief_add']['#value'] = t('Add @bundle', array('@bundle' => $bundle_lowercase));
    }
    if (isset($element['actions']['ief_add_existing']['#value'])) {
      $element['actions']['ief_add_existing']['#value'] = t('Use existing @bundle', array('@bundle' => $bundle_lowercase));
    }
  }

  $state = $form_state['inline_entity_form'][$element['#ief_id']];

  if (!empty($element['form'])) {
    $bundle = $info['bundles'][$state['form settings']['bundle']]['label'];
    $bundle_lowercase = drupal_strtolower($bundle);
    if ($state['form'] == 'add') {
      $element['form']['#title'] = t('Add @bundle', array('@bundle' => $bundle_lowercase));
      $element['form']['actions']['ief_add_save']['#value'] = t('Save @bundle', array('@bundle' => $bundle_lowercase));
    }
    elseif ($state['form'] == 'ief_add_existing') {
      $element['form']['#title'] = t('Select an existing @bundle', array('@bundle' => $bundle_lowercase));
      $element['form']['entity_id']['#title'] = check_plain($bundle);
      $element['form']['actions']['ief_reference_save']['#value'] = t('Select @bundle', array('@bundle' => $bundle_lowercase));
    }
    elseif ($element['form']['#op'] == 'clone') {
      $element['form']['#title'] = t('Clone @bundle', array('@bundle' => $bundle_lowercase));
      $element['form']['actions']['ief_clone_save']['#value'] = t('Save @bundle', array('@bundle' => $bundle_lowercase));
    }

    if (!empty($element['form']['#title'])) {
      $element['form']['ief_form_title'] = array(
        '#markup' => '<h4>' . $element['form']['#title'] . '</h4>',
        '#weight' => -100,
      );
      unset($element['form']['#title']);
    }
  }

  if (!empty($state['entities'])) {
    foreach ($state['entities'] as $delta => $entity_state) {
      if ($entity_state['form'] == 'edit') {
        $bundle = $info['bundles'][$element['entities'][$delta]['form']['#bundle']]['label'];
        $bundle_lowercase = drupal_strtolower($bundle);
        $element['entities'][$delta]['form']['actions']['ief_edit_save']['#value'] = t('Save @bundle', array('@bundle' => $bundle_lowercase));
      }
    }
  }

  // Force the parent element to always be rendered as a fieldset so that we
  // never lose the parent field title, description, and required indicators.
  $element['#type'] = 'fieldset';

  // Add support for the field help text.
  if (!empty($context['instance']['description'])) {
    $element['#description'] = field_filter_xss($context['instance']['description']);
  }
  else {
    $element['#description'] = '';
  }

  // Only re-add the cardinality description if you can add more than one
  // value, and this isn't an unlimited-value field.
  if ($context['field']['cardinality'] != FIELD_CARDINALITY_UNLIMITED && $context['field']['cardinality'] > 1) {
    if (!empty($element['#description'])) {
      $element['#description'] .= ' ';
    }
    $element['#description'] = t('You have added @entities_count out of @cardinality_count allowed.', array(
      '@entities_count' => count($state['entities']),
      '@cardinality_count' => $context['field']['cardinality'],
    ));
  }

  // Add the required marker to the title.
  if ($context['instance']['required']) {
    $element['#title'] .= theme('form_required_marker');
  }
}

/**
 * Implementation of hook_environment_switch().
 */
function deims_environment_switch($target_env, $current_env) {
  // Declare each optional development-related module
  $devel_modules = array(
    'context_ui',
    'devel',
    'devel_generate',
    'imagecache_ui',
    'update',
    'views_ui',
  );

  switch ($target_env) {
    case 'production':
      module_disable($devel_modules);
      drupal_set_message('Disabled development modules');

      // Ensure we use the production PASTA API.
      variable_set('eml_pasta_base_url', 'https://pasta.lternet.edu');

      // Environment indicator settings.
      variable_set('environment_indicator_enabled', FALSE);

      break;

    case 'development':
      module_enable($devel_modules);
      drupal_set_message('Enabled development modules');

      // Ensure we use the staging PASTA API for development.
      variable_set('eml_pasta_base_url', 'https://pasta-s.lternet.edu');

      // Debugging mail handler.
      variable_set('mail_system', array(
        'default-system' => 'HelperDebugMailLog',
      ));

      // Environment indicator settings.
      variable_set('environment_indicator_enabled', TRUE);
      variable_set('environment_indicator_text', 'DEIMS Development Site');
      break;
  }
}
