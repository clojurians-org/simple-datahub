/**
 * Tab properties for entity profile pages
 * @export
 * @interface ITabProperties
 */
export interface ITabProperties {
  id: Tab;
  title: string;
  component: string;
  lazyRender?: boolean;
}

/**
 * Lists the tabs available globally to each entity
 * @export
 * @enum {string}
 */
export enum Tab {
  Properties = 'properties',
  Comments = 'comments',
  Schema = 'schema',
  Ownership = 'ownership',
  SampleData = 'sample',
  Relationships = 'relationships',
  Metadata = 'metadata',
  Wiki = 'wiki'
}

/**
 * A lookup table for each Tabs enumeration
 * @type {Record<Tab, ITabProperties>}
 */
export const TabProperties: Record<Tab, ITabProperties> = {
  [Tab.Schema]: {
    id: Tab.Schema,
    // title: 'Schema',
    title: '模式',
    component: 'datasets/containers/dataset-schema'
  },
  [Tab.Properties]: {
    id: Tab.Properties,
    // title: 'Status',
    title: '状态',
    component: 'datasets/containers/dataset-properties'
  },
  [Tab.Ownership]: {
    id: Tab.Ownership,
    // title: 'Ownership',
    title: '所有者',
    component: 'datasets/containers/dataset-ownership'
  },
  [Tab.Comments]: {
    id: Tab.Comments,
    // title: 'Comments',
    title: '描述',
    component: ''
  },
  [Tab.SampleData]: {
    id: Tab.SampleData,
    // title: 'Sample Data',
    title: '样本数据',
    component: ''
  },
  /*
   ** Todo : META-9512 datasets - relationships view is unable to handle big payloads
   ** Adding lazy render as a workaround, so as to unblock rest of the tabs on the page.
   */
  [Tab.Relationships]: {
    id: Tab.Relationships,
    // title: 'Relationships',
    title: '依赖关系',
    component: 'datasets/dataset-relationships',
    lazyRender: true
  },
  [Tab.Metadata]: {
    id: Tab.Metadata,
    // title: 'Metadata',
    title: '元数据',
    component: 'feature-attributes'
  },
  [Tab.Wiki]: {
    id: Tab.Wiki,
    // title: 'Docs',
    title: '相关文档',
    component: 'institutional-memory/containers/tab',
    lazyRender: true
  }
};
