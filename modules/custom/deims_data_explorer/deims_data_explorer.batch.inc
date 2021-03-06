<?php

/**
 * _fetch_row_batch description
 * @param  array $options Array of options passed by the init.
 * @param  array $context Context passed back to the function.
 */
function _fetch_row_batch($query, $file, $columns, &$context) {
  // Set up our batch configuration information.
  if (empty($context['sandbox'])) {
    $context['sandbox']['progress'] = 0;
    $context['sandbox']['max'] = $query->countQuery()->execute()->fetchField();
  }

  $query->range($context['sandbox']['progress'], 5); //DEIMS_BATCH_LIMIT);
  $result = $query->execute();

  // Write out the CSV.
  $fp = fopen(drupal_realpath($file->uri), 'a');

  // Add the header row if we're on our first pass.
  if ($context['sandbox']['progress'] == 0 && !empty($columns)) {
    fputcsv($fp,$columns);
  }

  while ($row = $result->fetchAssoc()) {
    fputcsv($fp, $row);
    $context['sandbox']['progress']++;
  }
  fclose($fp);

  if ($context['sandbox']['progress'] != $context['sandbox']['max']) {
    $context['finished'] = ($context['sandbox']['progress'] >= $context['sandbox']['max']);
  }
}

/**
 * _process_file_for_download description
 * @param  object $file    The file object that is being acted upon.
 * @param  string $table   The name of the table that was queried.
 * @param  array  $context Context passed back to function.
 */
function _process_file_for_download($file,$table,$nid,&$context) {
  // Setting status = 0 marks the file as temporary which means it'll get
  // cleaned up automatically within 6 hours by Drupal.

  // Do we need to compress the file?
  if (($file->filesize / DRUPAL_KILOBYTE) > (DRUPAL_KILOBYTE * DEIMS_COMPRESSION_THRESHOLD)) {
    $uncompressed = $file;
    $file = file_save_data('');
    $fp = gzopen(drupal_realpath($file->uri), 'w9');
    gzwrite($fp, file_get_contents(drupal_realpath($uncompressed->uri)));
    gzclose($fp);
    file_delete($uncompressed);

    // Re-save the file to compute size.
    $file->status = 0;
    $file = file_move($file, file_create_filename($table . '_csv.gz', variable_get('deims_data_explorer_dir', 'public://data-downloads/')));
  }
  else {
    $file->status = 0;
    file_save($file);
  }
  $context['results']['file'] = $file;
  $context['results']['nid'] = $nid;
}

/**
 * _show_download_link
 * @param  [type] $success    [description]
 * @param  [type] $results    [description]
 * @param  [type] $operations [description]
 * @return [type]             [description]
 */
function _show_download_link($success, $results, $operations) {
  $batch = &batch_get();

  if ($success) {
    $path = "node/{$results['nid']}/data/download/{$results['file']->fid}";
    $batch['redirect'] = array(
      $path,
      array(
        'query' => array(
          'token' => drupal_get_token($path),
        ),
      ),
    );
  }
  else {
    $message = 'There was an error processing your request. Please try again and '
      . l('contact us', '/contact') . ' if you have repeated errors.';
      drupal_set_message($message);
    $batch['redirect'] = 'node/' . $results['nid'] . '/data';
  }

}
