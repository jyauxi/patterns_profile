<?php
/**
 * @file
 * Provides an option to select patterns to be executed during the site installation.
 */

/**
 * Implements hook_install_tasks().
 *
 */
function patterns_profile_install_tasks() {
  $tasks = array();
  $tasks['patterns_profile_settings_form'] = array(
      'display_name' => st('Run some Patterns'),
      'type' => 'form',
  );
  return $tasks;
}

/**
 * Implements patterns_profile_settings_form().
 */
function patterns_profile_settings_form($form, &$form_state, &$install_state) {
  // Set the install_profile variable employed by the function manually
  variable_set('install_profile', 'patterns_profile');
  $patterns = _patterns_io_get_patterns();
  // Set the status manually
  $patterns = $patterns[PATTERNS_STATUS_OK];
  // Display some example patterns to run
  $options = array();
  foreach($patterns as $pattern) {
    $options[$pattern->name] = $pattern->title .'<div class="description">'. $pattern->description .'</div>';
  }
  $form['patterns'] = array(
    '#type' => 'checkboxes',
    '#title' => t('Can\'t wait to try it out?. Run some testing patterns that will modify the configuration of your new site: '),
    '#description' => st("Patterns provide additional features and functionality to Drupal sites
        and save your time by setting them up automatically for you.
        Enable patterns_examples submodule after the installation
        is finished to find more Pattern examples."),
    '#options' => $options,
  );
  $form['submit'] = array(
      '#type' => 'submit',
      '#value' => st('Continue'),
  );
  return $form;
}

/**
 * Implements patterns_profile_settings_form_submit().
 * Merges and executes the selected Patterns.
 */
function patterns_profile_settings_form_submit($form, &$form_state) {
  // Retrieve selected values and prepare execution
  $patterns_files = array_filter($form_state['values']['patterns']);
  if (count($patterns_files)>0) {
    // Retrieve the object of the first pattern file
    $pattern = _patterns_db_get_pattern(array_shift($patterns_files));
    // Merge actions of rest of patterns in the first one if any
    $pids = array();
    foreach($patterns_files as $pattern_file) {
      $subpattern = _patterns_db_get_pattern($pattern_file);
      foreach ($subpattern->pattern['actions'] as $action) {
        $pattern->pattern['actions'][] = $action;
      }
      $pids[] = $subpattern->pid;
    }
    // Execute merged pattern
    patterns_start_engine($pattern, array('run-subpatterns' => TRUE));
    // If all the subpatterns were successfully executed, marked the original ones as run
    foreach($pids as $pid) {
      $query_params = array(
        ':time' => time(),
        ':pid' => $pid,
        ':en' => PATTERNS_STATUS_ENABLED,
      );
      db_query("UPDATE {patterns} SET status = :en, enabled = :time WHERE pid = :pid", $query_params);
    }
  }
}